#include "rigcanvas_dsp.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <new>
#include <vector>

namespace {
constexpr uint32_t kAbiVersion=1, kMaxChannels=2, kMaxNodes=32, kMaxIrSamples=4096;
constexpr float kPi=3.14159265358979323846f, kSilenceDb=-120.0f;
enum NodeType:int32_t { kDynamics=1, kDrive=2, kAmplifier=3, kCabinet=4 };
enum DynamicsMode:int32_t { kGate=0, kCompressor=1 };
float clampf(float x,float lo,float hi){return std::max(lo,std::min(x,hi));}
float dbToLinear(float db){return std::pow(10.0f,db/20.0f);}
double linearToDb(double x){if(!(x>0.0)||!std::isfinite(x))return kSilenceDb;return std::max(static_cast<double>(kSilenceDb),20.0*std::log10(x));}
float smoothCoefficient(float ms,uint32_t sr){return std::exp(-1.0f/(std::max(ms,0.05f)*0.001f*static_cast<float>(sr)));}
float lpCoefficient(float hz,uint32_t sr){return 1.0f-std::exp(-2.0f*kPi*clampf(hz,10.0f,static_cast<float>(sr)*0.45f)/static_cast<float>(sr));}

struct Node {
  int32_t type=0,mode=0; bool enabled=true;
  std::array<float,8> p{};
  std::array<float,kMaxChannels> envelope{},gain{1.0f,1.0f},driveLp{},ampLow{},ampMid{};
  std::vector<float> impulse,history; uint32_t historyPosition=0;
  Node(int32_t t,int32_t m,bool on,uint32_t channels):type(t),mode(m),enabled(on){
    if(t==kDynamics)p={-48,3,10,120,0,1,0,0};
    if(t==kDrive)p={8,0.55f,0,1,0,0,0,0};
    if(t==kAmplifier)p={8,0,0,0,0,0,0,0};
    if(t==kCabinet){p={1,0,0,0,0,0,0,0};history.resize(static_cast<size_t>(channels)*kMaxIrSamples,0);}
  }
};
struct Engine {
  uint32_t sampleRate,channels; std::vector<Node> nodes;
  double inputSquares=0,outputSquares=0; float inputPeak=0,outputPeak=0;
  uint32_t frames=0,enabledNodes=0;
  Engine(uint32_t sr,uint32_t ch):sampleRate(sr),channels(ch){}
};
Engine* engineOf(void* p){return static_cast<Engine*>(p);}
void resetMetrics(Engine& e){e.inputSquares=e.outputSquares=0;e.inputPeak=e.outputPeak=0;e.frames=0;e.enabledNodes=0;for(const auto& n:e.nodes)if(n.enabled)++e.enabledNodes;}

void processDynamics(Node& n,float* x,uint32_t ch,uint32_t sr){
  float detector=0;for(uint32_t c=0;c<ch;++c)detector=std::max(detector,std::abs(x[c]));
  float env=n.envelope[0];float coeff=smoothCoefficient(detector>env?n.p[2]:n.p[3],sr);
  env=coeff*env+(1-coeff)*detector;n.envelope[0]=env;
  float db=static_cast<float>(linearToDb(env)),target=1;
  if(n.mode==kGate){if(db<n.p[0])target=dbToLinear(clampf((db-n.p[0])*1.5f,-72,0));}
  else if(db>n.p[0]){float ratio=std::max(1.0f,n.p[1]);float reduction=n.p[0]+(db-n.p[0])/ratio-db;target=dbToLinear(reduction+n.p[4]);}
  else target=dbToLinear(n.p[4]);
  float time;
  if(n.mode==kGate)time=target<n.gain[0]?n.p[3]:n.p[2];
  else time=target<n.gain[0]?n.p[2]:n.p[3];
  float g=smoothCoefficient(time,sr);
  n.gain[0]=g*n.gain[0]+(1-g)*target;
  float mix=clampf(n.p[5],0,1);
  for(uint32_t c=0;c<ch;++c){float wet=x[c]*n.gain[0];x[c]=x[c]*(1-mix)+wet*mix;}
}
void processDrive(Node& n,float* x,uint32_t ch,uint32_t sr){
  float gain=dbToLinear(clampf(n.p[0],0,30)),tone=clampf(n.p[1],0,1);
  float coeff=lpCoefficient(500+tone*8500,sr),level=dbToLinear(n.p[2]),mix=clampf(n.p[3],0,1);
  for(uint32_t c=0;c<ch;++c){float dry=x[c];n.driveLp[c]+=coeff*(dry-n.driveLp[c]);float low=n.driveLp[c],high=dry-low;float wet=(std::tanh(low*gain)+std::tanh(high*gain*0.72f))*0.78f*level;x[c]=dry*(1-mix)+wet*mix;}
}
void processAmp(Node& n,float* x,uint32_t ch,uint32_t sr){
  float cl=lpCoefficient(180,sr),cm=lpCoefficient(1500,sr),gain=dbToLinear(clampf(n.p[0],0,30));
  float gl=dbToLinear(n.p[1]),gm=dbToLinear(n.p[2]),gh=dbToLinear(n.p[3]+n.p[4]*0.55f),master=dbToLinear(n.p[5]);
  for(uint32_t c=0;c<ch;++c){float in=x[c];n.ampLow[c]+=cl*(in-n.ampLow[c]);n.ampMid[c]+=cm*(in-n.ampMid[c]);float low=n.ampLow[c],mid=n.ampMid[c]-low,high=in-n.ampMid[c];x[c]=std::tanh((low*gl+mid*gm+high*gh)*gain)*master;}
}
void processCab(Node& n,float* x,uint32_t ch){
  float mix=clampf(n.p[0],0,1),level=dbToLinear(n.p[1]);
  if(n.impulse.empty()){for(uint32_t c=0;c<ch;++c)x[c]*=level;return;}
  uint32_t taps=static_cast<uint32_t>(n.impulse.size());
  for(uint32_t c=0;c<ch;++c){size_t base=static_cast<size_t>(c)*kMaxIrSamples;n.history[base+n.historyPosition]=x[c];float wet=0;
    for(uint32_t k=0;k<taps;++k){uint32_t pos=(n.historyPosition+kMaxIrSamples-k)%kMaxIrSamples;wet+=n.impulse[k]*n.history[base+pos];}
    x[c]=(x[c]*(1-mix)+wet*mix)*level;
  }
  n.historyPosition=(n.historyPosition+1)%kMaxIrSamples;
}
int32_t processBuffer(Engine& e,float* data,uint32_t count){
  if(data==nullptr||count==0||count>e.sampleRate*2U)return -1;
  resetMetrics(e);std::array<float,kMaxChannels> frame{};
  for(uint32_t i=0;i<count;++i){
    for(uint32_t c=0;c<e.channels;++c){float s=data[static_cast<size_t>(i)*e.channels+c];if(!std::isfinite(s))s=0;frame[c]=s;e.inputSquares+=static_cast<double>(s)*s;e.inputPeak=std::max(e.inputPeak,std::abs(s));}
    for(auto& n:e.nodes){if(!n.enabled)continue;switch(n.type){case kDynamics:processDynamics(n,frame.data(),e.channels,e.sampleRate);break;case kDrive:processDrive(n,frame.data(),e.channels,e.sampleRate);break;case kAmplifier:processAmp(n,frame.data(),e.channels,e.sampleRate);break;case kCabinet:processCab(n,frame.data(),e.channels);break;default:return -2;}}
    for(uint32_t c=0;c<e.channels;++c){float s=std::isfinite(frame[c])?clampf(frame[c],-16,16):0;data[static_cast<size_t>(i)*e.channels+c]=s;e.outputSquares+=static_cast<double>(s)*s;e.outputPeak=std::max(e.outputPeak,std::abs(s));}
  }
  e.frames=count;return 0;
}
}

extern "C" {
uint32_t rg_engine_abi_version(void){return kAbiVersion;}
void* rg_engine_create(uint32_t sr,uint32_t ch){if(sr<8000||sr>192000||ch==0||ch>kMaxChannels)return nullptr;try{return new(std::nothrow) Engine(sr,ch);}catch(...){return nullptr;}}
void rg_engine_destroy(void* p){delete engineOf(p);}
int32_t rg_engine_add_node(void* p,int32_t type,int32_t mode,int32_t enabled){Engine* e=engineOf(p);if(!e||e->nodes.size()>=kMaxNodes)return -1;if(type<kDynamics||type>kCabinet)return -2;if(type==kDynamics&&mode!=kGate&&mode!=kCompressor)return -3;try{e->nodes.emplace_back(type,mode,enabled!=0,e->channels);return static_cast<int32_t>(e->nodes.size()-1);}catch(...){return -4;}}
int32_t rg_engine_set_parameter(void* p,uint32_t ni,uint32_t pi,float value){
  Engine* e=engineOf(p);if(!e||ni>=e->nodes.size()||!std::isfinite(value))return -1;Node& n=e->nodes[ni];uint32_t count=0;float lo=0,hi=1;
  switch(n.type){
    case kDynamics:count=6;if(pi==0){lo=-80;hi=0;}else if(pi==1){lo=1;hi=20;}else if(pi==2){lo=0.1f;hi=1000;}else if(pi==3){lo=5;hi=3000;}else if(pi==4){lo=-24;hi=24;}break;
    case kDrive:count=4;if(pi==0){lo=0;hi=30;}else if(pi==1||pi==3){lo=0;hi=1;}else if(pi==2){lo=-24;hi=12;}break;
    case kAmplifier:count=6;if(pi==0){lo=0;hi=30;}else{lo=-12;hi=12;}break;
    case kCabinet:count=2;if(pi==0){lo=0;hi=1;}else{lo=-24;hi=12;}break;default:return -2;
  }
  if(pi>=count)return -3;n.p[pi]=clampf(value,lo,hi);return 0;
}
int32_t rg_engine_set_cabinet_ir(void* p,uint32_t ni,const float* samples,uint32_t count){
  Engine* e=engineOf(p);if(!e||ni>=e->nodes.size()||!samples||count==0||count>kMaxIrSamples||e->nodes[ni].type!=kCabinet)return -1;
  try{std::vector<float> next;next.reserve(count);for(uint32_t i=0;i<count;++i){if(!std::isfinite(samples[i]))return -2;next.push_back(clampf(samples[i],-4,4));}Node& n=e->nodes[ni];n.impulse.swap(next);std::fill(n.history.begin(),n.history.end(),0);n.historyPosition=0;return 0;}catch(...){return -3;}
}
int32_t rg_engine_process(void* p,float* data,uint32_t frames){Engine* e=engineOf(p);return e?processBuffer(*e,data,frames):-1;}
int32_t rg_engine_run_test_tone(void* p,float hz,uint32_t ms){
  Engine* e=engineOf(p);if(!e||!std::isfinite(hz)||hz<20||hz>=static_cast<float>(e->sampleRate)*0.45f||ms==0||ms>2000)return -1;
  uint32_t frames=static_cast<uint32_t>(e->sampleRate)*ms/1000;if(frames==0)return -2;
  try{std::vector<float> data(static_cast<size_t>(frames)*e->channels);for(uint32_t i=0;i<frames;++i){float phase=2*kPi*hz*static_cast<float>(i)/static_cast<float>(e->sampleRate),s=0.35f*std::sin(phase);for(uint32_t c=0;c<e->channels;++c)data[static_cast<size_t>(i)*e->channels+c]=s;}return processBuffer(*e,data.data(),frames);}catch(...){return -3;}
}
double rg_engine_input_rms_db(void* p){Engine* e=engineOf(p);if(!e||e->frames==0)return kSilenceDb;double count=static_cast<double>(e->frames)*e->channels;return linearToDb(std::sqrt(e->inputSquares/count));}
double rg_engine_output_rms_db(void* p){Engine* e=engineOf(p);if(!e||e->frames==0)return kSilenceDb;double count=static_cast<double>(e->frames)*e->channels;return linearToDb(std::sqrt(e->outputSquares/count));}
double rg_engine_input_peak_db(void* p){Engine* e=engineOf(p);return e?linearToDb(e->inputPeak):kSilenceDb;}
double rg_engine_output_peak_db(void* p){Engine* e=engineOf(p);return e?linearToDb(e->outputPeak):kSilenceDb;}
uint32_t rg_engine_processed_frames(void* p){Engine* e=engineOf(p);return e?e->frames:0;}
uint32_t rg_engine_enabled_node_count(void* p){Engine* e=engineOf(p);return e?static_cast<uint32_t>(std::count_if(e->nodes.begin(),e->nodes.end(),[](const Node& n){return n.enabled;})):0;}
}
