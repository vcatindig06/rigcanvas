#include "rigcanvas_dsp.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <new>
#include <limits>
#include <vector>

namespace {
constexpr uint32_t kAbiVersion = 3, kMaxChannels = 2, kMaxNodes = 32, kMaxIrFrames = 4096;
constexpr float kPi = 3.14159265358979323846f, kSilenceDb = -120.0f;
enum NodeType : int32_t { kDynamics=1, kDrive=2, kAmplifier=3, kCabinet=4, kModulation=5, kDelay=6, kReverb=7, kEqualizer=8 };
enum DynamicsMode : int32_t { kGate=0, kCompressor=1 };
enum ModulationMode : int32_t { kChorus=0, kTremolo=1, kFlanger=2, kVibrato=3, kPhaser=4, kAutoWah=5, kRotary=6 };
enum DelayMode : int32_t { kStandardDelay=0, kPingPongDelay=1 };

float clampf(float v,float lo,float hi){return std::max(lo,std::min(v,hi));}
float dbToLinear(float db){return std::pow(10.0f,db/20.0f);}
double linearToDb(double v){if(!(v>0.0)||!std::isfinite(v))return kSilenceDb;return std::max(static_cast<double>(kSilenceDb),20.0*std::log10(v));}
float smoothCoefficient(float ms,uint32_t sr){return std::exp(-1.0f/(std::max(ms,0.05f)*0.001f*static_cast<float>(sr)));}
float lpCoefficient(float hz,uint32_t sr){return 1.0f-std::exp(-2.0f*kPi*clampf(hz,10.0f,static_cast<float>(sr)*0.45f)/static_cast<float>(sr));}
uint32_t modulo(int64_t value,uint32_t size){const int64_t n=static_cast<int64_t>(size);return static_cast<uint32_t>((value%n+n)%n);}

struct Node {
  int32_t type=0,mode=0; bool enabled=true; std::array<float,8> p{};
  std::array<float,kMaxChannels> envelope{},gain{1.0f,1.0f},driveLp{},ampLow{},ampMid{};
  std::vector<float> impulse,history; uint32_t impulseFrames=0,impulseChannels=1,historyPosition=0;
  std::array<float,kMaxChannels> cabLow{},cabHigh{};
  std::vector<float> modBuffer; uint32_t modFrames=0,modPosition=0; double phase=0;
  std::array<float,kMaxChannels> modTone{};
  std::array<std::array<float,4>,kMaxChannels> phaserState{};
  std::array<float,kMaxChannels> phaserFeedback{},wahEnvelope{},wahLow{},wahBand{};
  std::vector<float> delayBuffer; uint32_t delayFrames=0,delayPosition=0;
  std::array<float,kMaxChannels> delayTone{};
  std::vector<float> preDelay; uint32_t preFrames=0,prePosition=0;
  std::array<std::vector<float>,4> comb;
  std::array<uint32_t,4> combFrames{},combPosition{};
  std::array<std::array<float,kMaxChannels>,4> combDamp{};
  std::array<float,kMaxChannels> eqLow{},eqLowMid{},eqHighMid{};

  Node(int32_t t,int32_t m,bool on,uint32_t ch,uint32_t sr):type(t),mode(m),enabled(on){
    if(t==kDynamics)p={-48,3,10,120,0,1,0,0};
    else if(t==kDrive)p={8,0.55f,0,1,0,0,0,0};
    else if(t==kAmplifier)p={8,0,0,0,0,0,0,0};
    else if(t==kCabinet){p={1,0,80,11000,0,0,0,0};history.resize(static_cast<size_t>(ch)*kMaxIrFrames,0);}
    else if(t==kModulation){p={1.2f,45,55,25,0,0,0,0};modFrames=std::max(2U,sr/10U);modBuffer.resize(static_cast<size_t>(ch)*modFrames,0);}
    else if(t==kDelay){p={480,32,9000,24,0,0,0,0};delayFrames=sr*2U+1U;delayBuffer.resize(static_cast<size_t>(ch)*delayFrames,0);}
    else if(t==kReverb){p={5.5f,25,55,30,0,0,0,0};preFrames=std::max(2U,sr/4U+1U);preDelay.resize(static_cast<size_t>(ch)*preFrames,0);const uint32_t ms[4]={29,37,41,43};for(uint32_t i=0;i<4;++i){combFrames[i]=std::max(2U,sr*ms[i]/1000U);comb[i].resize(static_cast<size_t>(ch)*combFrames[i],0);}}
    else if(t==kEqualizer)p={0,0,0,0,0,0,0,0};
  }
};
struct Engine {
  uint32_t sampleRate,channels;std::vector<Node> nodes;
  double inSquares=0,outSquares=0;float inPeak=0,outPeak=0;
  uint32_t frames=0,enabledNodes=0;
  Engine(uint32_t sr,uint32_t ch):sampleRate(sr),channels(ch){}
};
Engine* engineOf(void* p){return static_cast<Engine*>(p);}
void resetMetrics(Engine& e){e.inSquares=e.outSquares=0;e.inPeak=e.outPeak=0;e.frames=0;e.enabledNodes=0;for(const auto& n:e.nodes)if(n.enabled)++e.enabledNodes;}

void processDynamics(Node& n,float* x,uint32_t ch,uint32_t sr){
  float detector=0;for(uint32_t c=0;c<ch;++c)detector=std::max(detector,std::abs(x[c]));
  float env=n.envelope[0],ec=smoothCoefficient(detector>env?n.p[2]:n.p[3],sr);n.envelope[0]=ec*env+(1-ec)*detector;
  float db=static_cast<float>(linearToDb(n.envelope[0])),target=1;
  if(n.mode==kGate){if(db<n.p[0])target=dbToLinear(clampf((db-n.p[0])*1.5f,-72,0));}
  else if(db>n.p[0]){float ratio=std::max(1.0f,n.p[1]);target=dbToLinear(n.p[0]+(db-n.p[0])/ratio-db+n.p[4]);}
  else target=dbToLinear(n.p[4]);
  float t=n.mode==kGate?(target<n.gain[0]?n.p[3]:n.p[2]):(target<n.gain[0]?n.p[2]:n.p[3]);
  float gc=smoothCoefficient(t,sr);n.gain[0]=gc*n.gain[0]+(1-gc)*target;float mix=clampf(n.p[5],0,1);
  for(uint32_t c=0;c<ch;++c){float wet=x[c]*n.gain[0];x[c]=x[c]*(1-mix)+wet*mix;}
}
void processDrive(Node& n,float* x,uint32_t ch,uint32_t sr){
  float gain=dbToLinear(clampf(n.p[0],0,30)),tone=clampf(n.p[1],0,1),coef=lpCoefficient(500+tone*8500,sr),level=dbToLinear(n.p[2]),mix=clampf(n.p[3],0,1);
  for(uint32_t c=0;c<ch;++c){float dry=x[c];n.driveLp[c]+=coef*(dry-n.driveLp[c]);float low=n.driveLp[c],high=dry-low;float wet=(std::tanh(low*gain)+std::tanh(high*gain*0.72f))*0.78f*level;x[c]=dry*(1-mix)+wet*mix;}
}
void processAmp(Node& n,float* x,uint32_t ch,uint32_t sr){
  float cl=lpCoefficient(180,sr),cm=lpCoefficient(1500,sr),gain=dbToLinear(clampf(n.p[0],0,30));
  float gl=dbToLinear(n.p[1]),gm=dbToLinear(n.p[2]),gh=dbToLinear(n.p[3]+n.p[4]*0.55f),master=dbToLinear(n.p[5]);
  for(uint32_t c=0;c<ch;++c){float in=x[c];n.ampLow[c]+=cl*(in-n.ampLow[c]);n.ampMid[c]+=cm*(in-n.ampMid[c]);float low=n.ampLow[c],mid=n.ampMid[c]-low,high=in-n.ampMid[c];x[c]=std::tanh((low*gl+mid*gm+high*gh)*gain)*master;}
}
void processCab(Node& n,float* x,uint32_t ch,uint32_t sr){
  float mix=clampf(n.p[0],0,1),level=dbToLinear(n.p[1]),cl=lpCoefficient(clampf(n.p[2],20,500),sr),chc=lpCoefficient(clampf(n.p[3],2000,20000),sr);
  for(uint32_t c=0;c<ch;++c){float dry=x[c],wet=dry;if(n.impulseFrames){size_t base=static_cast<size_t>(c)*kMaxIrFrames;n.history[base+n.historyPosition]=dry;wet=0;uint32_t irc=n.impulseChannels==1?0:c;for(uint32_t k=0;k<n.impulseFrames;++k){uint32_t pos=modulo(static_cast<int64_t>(n.historyPosition)-k,kMaxIrFrames);wet+=n.impulse[static_cast<size_t>(k)*n.impulseChannels+irc]*n.history[base+pos];}}
    n.cabLow[c]+=cl*(wet-n.cabLow[c]);float hp=wet-n.cabLow[c];n.cabHigh[c]+=chc*(hp-n.cabHigh[c]);x[c]=(dry*(1-mix)+n.cabHigh[c]*mix)*level;}
  if(n.impulseFrames)n.historyPosition=(n.historyPosition+1)%kMaxIrFrames;
}
float readFractional(const std::vector<float>& b,size_t base,uint32_t write,uint32_t size,float delay){
  float pos=static_cast<float>(write)-delay;if(pos<0)pos+=size;float floorPos=std::floor(pos);uint32_t a=static_cast<uint32_t>(floorPos)%size,bb=(a+1)%size;float f=pos-floorPos;float va=b[base+a];return va+(b[base+bb]-va)*f;
}
void processMod(Node& n,float* x,uint32_t ch,uint32_t sr){
  const float rate=clampf(n.p[0],0.1f,10),depth=clampf(n.p[1]/100,0,1),tone=clampf(n.p[2]/100,0,1),mix=clampf(n.p[3]/100,0,1);
  const float lfo=static_cast<float>(std::sin(n.phase));
  if(n.mode==kTremolo){
    const float gain=1.0f-depth*(0.5f-0.5f*lfo);
    for(uint32_t c=0;c<ch;++c)x[c]*=(1-mix)+mix*gain;
    n.phase+=2.0*static_cast<double>(kPi)*rate/static_cast<double>(sr);
    if(n.phase>=2.0*static_cast<double>(kPi))n.phase-=2.0*static_cast<double>(kPi);
    return;
  }
  if(n.mode==kPhaser){
    const float sweepHz=250.0f+2600.0f*depth*(0.5f+0.5f*lfo);
    const float tangent=std::tan(kPi*sweepHz/static_cast<float>(sr));
    const float coefficient=(1.0f-tangent)/(1.0f+tangent);
    const float feedback=clampf(n.p[2]/100.0f,0.0f,0.85f);
    for(uint32_t c=0;c<ch;++c){
      const float dry=x[c];
      float value=dry+n.phaserFeedback[c]*feedback;
      for(uint32_t stage=0;stage<4;++stage){
        const float y=coefficient*value+n.phaserState[c][stage];
        n.phaserState[c][stage]=value-coefficient*y;
        value=y;
      }
      n.phaserFeedback[c]=value;
      const float wet=0.5f*(dry+value);
      x[c]=dry*(1.0f-mix)+wet*mix;
    }
    n.phase+=2.0*static_cast<double>(kPi)*rate/static_cast<double>(sr);
    if(n.phase>=2.0*static_cast<double>(kPi))n.phase-=2.0*static_cast<double>(kPi);
    return;
  }
  if(n.mode==kAutoWah){
    const float sensitivity=clampf(n.p[0],0.1f,10.0f);
    const float resonance=clampf(n.p[2]/100.0f,0.0f,1.0f);
    const float damping=2.0f-1.65f*resonance;
    for(uint32_t c=0;c<ch;++c){
      const float dry=x[c],detector=std::abs(dry);
      const float envCoeff=smoothCoefficient(detector>n.wahEnvelope[c]?8.0f:120.0f,sr);
      n.wahEnvelope[c]=envCoeff*n.wahEnvelope[c]+(1.0f-envCoeff)*detector;
      const float envelope=clampf(n.wahEnvelope[c]*sensitivity*0.35f,0.0f,1.0f);
      const float frequency=300.0f+2200.0f*depth*envelope;
      const float f=clampf(2.0f*std::sin(kPi*frequency/static_cast<float>(sr)),0.001f,0.95f);
      n.wahLow[c]+=f*n.wahBand[c];
      const float high=dry-n.wahLow[c]-damping*n.wahBand[c];
      n.wahBand[c]+=f*high;
      const float wet=n.wahBand[c]*1.8f;
      x[c]=dry*(1.0f-mix)+wet*mix;
    }
    return;
  }
  if(n.mode==kRotary){
    const float coef=lpCoefficient(700.0f+tone*10000.0f,sr);
    for(uint32_t c=0;c<ch;++c){
      const float dry=x[c];
      const float channelPhase=static_cast<float>(n.phase)+(c==0?0.0f:kPi);
      const float channelLfo=std::sin(channelPhase);
      const float delayMs=0.3f+1.8f*depth*(0.5f+0.5f*channelLfo);
      const float delay=clampf(delayMs*sr/1000.0f,1.0f,static_cast<float>(n.modFrames-2));
      const size_t base=static_cast<size_t>(c)*n.modFrames;
      n.modBuffer[base+n.modPosition]=dry;
      const float delayed=readFractional(n.modBuffer,base,n.modPosition,n.modFrames,delay);
      n.modTone[c]+=coef*(delayed-n.modTone[c]);
      const float rotorGain=0.82f+0.18f*(0.5f+0.5f*channelLfo);
      x[c]=dry*(1.0f-mix)+n.modTone[c]*rotorGain*mix;
    }
    n.modPosition=(n.modPosition+1)%n.modFrames;
    n.phase+=2.0*static_cast<double>(kPi)*rate/static_cast<double>(sr);
    if(n.phase>=2.0*static_cast<double>(kPi))n.phase-=2.0*static_cast<double>(kPi);
    return;
  }
  const float baseMs=n.mode==kFlanger?1.5f:12.0f,depthMs=n.mode==kFlanger?4.0f:10.0f;
  const float delay=clampf((baseMs+depthMs*depth*(0.5f+0.5f*lfo))*sr/1000.0f,1.0f,static_cast<float>(n.modFrames-2));
  const float coef=lpCoefficient(700.0f+tone*10000.0f,sr);
  for(uint32_t c=0;c<ch;++c){
    const float dry=x[c];
    const size_t base=static_cast<size_t>(c)*n.modFrames;
    n.modBuffer[base+n.modPosition]=dry;
    const float wet=readFractional(n.modBuffer,base,n.modPosition,n.modFrames,delay);
    n.modTone[c]+=coef*(wet-n.modTone[c]);
    x[c]=dry*(1.0f-mix)+n.modTone[c]*mix;
  }
  n.modPosition=(n.modPosition+1)%n.modFrames;
  n.phase+=2.0*static_cast<double>(kPi)*rate/static_cast<double>(sr);
  if(n.phase>=2.0*static_cast<double>(kPi))n.phase-=2.0*static_cast<double>(kPi);
}
void processDelay(Node& n,float* x,uint32_t ch,uint32_t sr){
  uint32_t delay=std::max(1U,std::min(n.delayFrames-1,static_cast<uint32_t>(clampf(n.p[0],1,2000)*sr/1000)));
  float feedback=clampf(n.p[1]/100,0,0.95f),coef=lpCoefficient(clampf(n.p[2],1000,20000),sr),mix=clampf(n.p[3]/100,0,1);
  std::array<float,kMaxChannels> dry{},delayed{},filtered{};
  for(uint32_t c=0;c<ch;++c){dry[c]=x[c];uint32_t src=n.mode==kPingPongDelay&&ch==2?1-c:c;size_t base=static_cast<size_t>(src)*n.delayFrames;uint32_t pos=modulo(static_cast<int64_t>(n.delayPosition)-delay,n.delayFrames);delayed[c]=n.delayBuffer[base+pos];}
  for(uint32_t c=0;c<ch;++c){n.delayTone[c]+=coef*(delayed[c]-n.delayTone[c]);filtered[c]=n.delayTone[c];x[c]=dry[c]*(1-mix)+filtered[c]*mix;}
  for(uint32_t c=0;c<ch;++c){uint32_t fb=n.mode==kPingPongDelay&&ch==2?1-c:c;size_t base=static_cast<size_t>(c)*n.delayFrames;n.delayBuffer[base+n.delayPosition]=dry[c]+filtered[fb]*feedback;}
  n.delayPosition=(n.delayPosition+1)%n.delayFrames;
}
void processReverb(Node& n,float* x,uint32_t ch,uint32_t sr){
  float decay=clampf(n.p[0],0.1f,60),tone=clampf(n.p[2]/100,0,1),mix=clampf(n.p[3]/100,0,1),coef=lpCoefficient(500+tone*11000,sr);
  uint32_t pre=std::min(n.preFrames-1,static_cast<uint32_t>(clampf(n.p[1],0,250)*sr/1000));
  std::array<float,kMaxChannels> input{},wet{};
  for(uint32_t c=0;c<ch;++c){size_t base=static_cast<size_t>(c)*n.preFrames;n.preDelay[base+n.prePosition]=x[c];uint32_t pos=modulo(static_cast<int64_t>(n.prePosition)-pre,n.preFrames);input[c]=n.preDelay[base+pos];}
  for(uint32_t i=0;i<4;++i){uint32_t len=n.combFrames[i];float fb=std::pow(0.001f,(static_cast<float>(len)/sr)/decay);
    for(uint32_t c=0;c<ch;++c){size_t base=static_cast<size_t>(c)*len;float d=n.comb[i][base+n.combPosition[i]];n.combDamp[i][c]+=coef*(d-n.combDamp[i][c]);n.comb[i][base+n.combPosition[i]]=input[c]+n.combDamp[i][c]*fb;wet[c]+=d*0.25f;}
    n.combPosition[i]=(n.combPosition[i]+1)%len;
  }
  for(uint32_t c=0;c<ch;++c)x[c]=x[c]*(1-mix)+wet[c]*mix;
  n.prePosition=(n.prePosition+1)%n.preFrames;
}
void processEq(Node& n,float* x,uint32_t ch,uint32_t sr){
  float c1=lpCoefficient(180,sr),c2=lpCoefficient(600,sr),c3=lpCoefficient(2500,sr);
  float g1=dbToLinear(n.p[0]),g2=dbToLinear(n.p[1]),g3=dbToLinear(n.p[2]),g4=dbToLinear(n.p[3]),out=dbToLinear(n.p[4]);
  for(uint32_t c=0;c<ch;++c){float in=x[c];n.eqLow[c]+=c1*(in-n.eqLow[c]);n.eqLowMid[c]+=c2*(in-n.eqLowMid[c]);n.eqHighMid[c]+=c3*(in-n.eqHighMid[c]);float low=n.eqLow[c],lm=n.eqLowMid[c]-low,hm=n.eqHighMid[c]-n.eqLowMid[c],high=in-n.eqHighMid[c];x[c]=(low*g1+lm*g2+hm*g3+high*g4)*out;}
}

int32_t processBuffer(Engine& e,float* data,uint32_t count){
  if(!data||count==0||count>e.sampleRate*2U)return -1;resetMetrics(e);std::array<float,kMaxChannels> frame{};
  for(uint32_t i=0;i<count;++i){
    for(uint32_t c=0;c<e.channels;++c){float s=data[static_cast<size_t>(i)*e.channels+c];if(!std::isfinite(s))s=0;frame[c]=s;e.inSquares+=static_cast<double>(s)*s;e.inPeak=std::max(e.inPeak,std::abs(s));}
    for(auto& n:e.nodes){if(!n.enabled)continue;switch(n.type){
      case kDynamics:processDynamics(n,frame.data(),e.channels,e.sampleRate);break;
      case kDrive:processDrive(n,frame.data(),e.channels,e.sampleRate);break;
      case kAmplifier:processAmp(n,frame.data(),e.channels,e.sampleRate);break;
      case kCabinet:processCab(n,frame.data(),e.channels,e.sampleRate);break;
      case kModulation:processMod(n,frame.data(),e.channels,e.sampleRate);break;
      case kDelay:processDelay(n,frame.data(),e.channels,e.sampleRate);break;
      case kReverb:processReverb(n,frame.data(),e.channels,e.sampleRate);break;
      case kEqualizer:processEq(n,frame.data(),e.channels,e.sampleRate);break;
      default:return -2;
    }}
    for(uint32_t c=0;c<e.channels;++c){float s=std::isfinite(frame[c])?clampf(frame[c],-16,16):0;data[static_cast<size_t>(i)*e.channels+c]=s;e.outSquares+=static_cast<double>(s)*s;e.outPeak=std::max(e.outPeak,std::abs(s));}
  }
  e.frames=count;return 0;
}
} // namespace

extern "C" {
uint32_t rg_engine_abi_version(void){return kAbiVersion;}
void* rg_engine_create(uint32_t sr,uint32_t ch){if(sr<8000||sr>192000||ch==0||ch>kMaxChannels)return nullptr;try{return new(std::nothrow) Engine(sr,ch);}catch(...){return nullptr;}}
void rg_engine_destroy(void* p){delete engineOf(p);}
int32_t rg_engine_add_node(void* p,int32_t type,int32_t mode,int32_t enabled){
  Engine* e=engineOf(p);if(!e||e->nodes.size()>=kMaxNodes)return -1;if(type<kDynamics||type>kEqualizer)return -2;
  if(type==kDynamics&&mode!=kGate&&mode!=kCompressor)return -3;
  if(type==kModulation&&(mode<kChorus||mode>kRotary))return -4;
  if(type==kDelay&&mode!=kStandardDelay&&mode!=kPingPongDelay)return -5;
  if(type!=kDynamics&&type!=kModulation&&type!=kDelay&&mode!=0)return -6;
  try{e->nodes.emplace_back(type,mode,enabled!=0,e->channels,e->sampleRate);return static_cast<int32_t>(e->nodes.size()-1);}catch(...){return -7;}
}
int32_t rg_engine_set_parameter(void* p,uint32_t ni,uint32_t pi,float v){
  Engine* e=engineOf(p);if(!e||ni>=e->nodes.size()||!std::isfinite(v))return -1;Node& n=e->nodes[ni];uint32_t count=0;float lo=0,hi=1;
  switch(n.type){
    case kDynamics:count=6;if(pi==0){lo=-80;hi=0;}else if(pi==1){lo=1;hi=20;}else if(pi==2){lo=0.1f;hi=1000;}else if(pi==3){lo=5;hi=3000;}else if(pi==4){lo=-24;hi=24;}break;
    case kDrive:count=4;if(pi==0){lo=0;hi=30;}else if(pi==1||pi==3){lo=0;hi=1;}else if(pi==2){lo=-24;hi=12;}break;
    case kAmplifier:count=6;if(pi==0){lo=0;hi=30;}else{lo=-12;hi=12;}break;
    case kCabinet:count=4;if(pi==0){lo=0;hi=1;}else if(pi==1){lo=-24;hi=12;}else if(pi==2){lo=20;hi=500;}else if(pi==3){lo=2000;hi=20000;}break;
    case kModulation:count=4;if(pi==0){lo=0.1f;hi=10;}else{lo=0;hi=100;}break;
    case kDelay:count=4;if(pi==0){lo=1;hi=2000;}else if(pi==1){lo=0;hi=95;}else if(pi==2){lo=1000;hi=20000;}else{lo=0;hi=100;}break;
    case kReverb:count=4;if(pi==0){lo=0.1f;hi=60;}else if(pi==1){lo=0;hi=250;}else{lo=0;hi=100;}break;
    case kEqualizer:count=5;if(pi<4){lo=-18;hi=18;}else{lo=-24;hi=12;}break;
    default:return -2;
  }
  if(pi>=count)return -3;n.p[pi]=clampf(v,lo,hi);return 0;
}
int32_t rg_engine_set_cabinet_ir(void* p,uint32_t ni,const float* samples,uint32_t frames,uint32_t irChannels){
  Engine* e=engineOf(p);if(!e||ni>=e->nodes.size()||!samples||frames==0||frames>kMaxIrFrames||irChannels==0||irChannels>kMaxChannels||(irChannels==2U&&e->channels!=2U)||e->nodes[ni].type!=kCabinet)return -1;
  try{std::vector<float> next;next.reserve(static_cast<size_t>(frames)*irChannels);for(size_t i=0;i<static_cast<size_t>(frames)*irChannels;++i){if(!std::isfinite(samples[i]))return -2;next.push_back(clampf(samples[i],-4,4));}Node& n=e->nodes[ni];n.impulse.swap(next);n.impulseFrames=frames;n.impulseChannels=irChannels;std::fill(n.history.begin(),n.history.end(),0);n.historyPosition=0;return 0;}catch(...){return -3;}
}
int32_t rg_engine_process(void* p,float* data,uint32_t frames){Engine* e=engineOf(p);return e?processBuffer(*e,data,frames):-1;}
int32_t rg_engine_run_test_tone(void* p,float hz,uint32_t ms){
  Engine* e=engineOf(p);if(!e||!std::isfinite(hz)||hz<20||hz>=static_cast<float>(e->sampleRate)*0.45f||ms==0||ms>2000)return -1;
  uint32_t frames=static_cast<uint32_t>(e->sampleRate)*ms/1000;if(!frames)return -2;
  try{std::vector<float> data(static_cast<size_t>(frames)*e->channels);for(uint32_t i=0;i<frames;++i){float phase=2*kPi*hz*static_cast<float>(i)/static_cast<float>(e->sampleRate),s=0.35f*std::sin(phase);for(uint32_t c=0;c<e->channels;++c)data[static_cast<size_t>(i)*e->channels+c]=s;}return processBuffer(*e,data.data(),frames);}catch(...){return -3;}
}
double rg_engine_input_rms_db(void* p){Engine* e=engineOf(p);if(!e||!e->frames)return kSilenceDb;double count=static_cast<double>(e->frames)*e->channels;return linearToDb(std::sqrt(e->inSquares/count));}
double rg_engine_output_rms_db(void* p){Engine* e=engineOf(p);if(!e||!e->frames)return kSilenceDb;double count=static_cast<double>(e->frames)*e->channels;return linearToDb(std::sqrt(e->outSquares/count));}
double rg_engine_input_peak_db(void* p){Engine* e=engineOf(p);return e?linearToDb(e->inPeak):kSilenceDb;}
double rg_engine_output_peak_db(void* p){Engine* e=engineOf(p);return e?linearToDb(e->outPeak):kSilenceDb;}
uint32_t rg_engine_processed_frames(void* p){Engine* e=engineOf(p);return e?e->frames:0;}
uint32_t rg_engine_enabled_node_count(void* p){Engine* e=engineOf(p);if(!e)return 0;uint32_t count=0;for(const auto& n:e->nodes)if(n.enabled)++count;return count;}
uint32_t rg_engine_node_count(void* p){Engine* e=engineOf(p);return e?static_cast<uint32_t>(e->nodes.size()):0;}
int32_t rg_engine_get_node_type(void* p,uint32_t ni){Engine* e=engineOf(p);if(!e||ni>=e->nodes.size())return -1;return e->nodes[ni].type;}
int32_t rg_engine_get_node_enabled(void* p,uint32_t ni){Engine* e=engineOf(p);if(!e||ni>=e->nodes.size())return -1;return e->nodes[ni].enabled?1:0;}
int32_t rg_engine_set_node_enabled(void* p,uint32_t ni,int32_t enabled){Engine* e=engineOf(p);if(!e||ni>=e->nodes.size())return -1;if(enabled!=0&&enabled!=1)return -2;e->nodes[ni].enabled=enabled!=0;return 0;}
double rg_engine_get_parameter(void* p,uint32_t ni,uint32_t pi){
  Engine* e=engineOf(p);
  if(!e||ni>=e->nodes.size())return std::numeric_limits<double>::quiet_NaN();
  const Node& n=e->nodes[ni];
  uint32_t count=0;
  switch(n.type){
    case kDynamics:count=6;break;
    case kDrive:count=4;break;
    case kAmplifier:count=6;break;
    case kCabinet:count=4;break;
    case kModulation:count=4;break;
    case kDelay:count=4;break;
    case kReverb:count=4;break;
    case kEqualizer:count=5;break;
    default:return std::numeric_limits<double>::quiet_NaN();
  }
  if(pi>=count)return std::numeric_limits<double>::quiet_NaN();
  return static_cast<double>(n.p[pi]);
}
int32_t rg_engine_move_node(void* p,uint32_t from,uint32_t to){
  Engine* e=engineOf(p);
  if(!e||from>=e->nodes.size()||to>=e->nodes.size())return -1;
  if(from==to)return 0;
  if(from<to)std::rotate(e->nodes.begin()+from,e->nodes.begin()+from+1,e->nodes.begin()+to+1);
  else std::rotate(e->nodes.begin()+to,e->nodes.begin()+from,e->nodes.begin()+from+1);
  return 0;
}
int32_t rg_engine_remove_node(void* p,uint32_t ni){
  Engine* e=engineOf(p);
  if(!e||ni>=e->nodes.size())return -1;
  e->nodes.erase(e->nodes.begin()+ni);
  return 0;
}
}
