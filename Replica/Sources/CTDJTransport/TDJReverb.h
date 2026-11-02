#ifndef TDJ_REVERB_H
#define TDJ_REVERB_H

typedef struct {
    float *data;
    unsigned length, cursor, valid;
} reverb_line;

typedef struct {
    float *storage;
    size_t storage_samples;
    reverb_line tank[8], diffuser[2][4], early[2];
    ramp feedback[8], tone;
    double damping[8], dc[8], input_low[2], input_high[2];
    double input_hp, input_lp, dc_pole, rate;
    double decay_seconds;
    unsigned predelay, early_taps[3];
    bool ice;
} stereo_reverb;

static unsigned reverb_prime(unsigned n) {
    if(n<3) return 3;
    n|=1;
    for(;;n+=2) {
        bool prime=true;
        for(unsigned d=3;d<=n/d;d+=2) if(n%d==0) { prime=false; break; }
        if(prime) return n;
    }
}

static bool reverb_init(stereo_reverb *v,double rate) {
    static const double tank_seconds[8]={0.0297,0.0371,0.0411,0.0437,0.0531,0.0617,0.0713,0.0797};
    static const double diffusion_seconds[2][4]={
        {0.00477,0.00359,0.01273,0.00931},
        {0.00523,0.00397,0.01331,0.01003}
    };
    v->rate=rate;
    for(int i=0;i<8;i++) {
        v->tank[i].length=reverb_prime((unsigned)ceil(rate*tank_seconds[i]));
        v->storage_samples+=v->tank[i].length;
    }
    for(int ch=0;ch<2;ch++) {
        for(int i=0;i<4;i++) {
            v->diffuser[ch][i].length=reverb_prime((unsigned)ceil(rate*diffusion_seconds[ch][i]));
            v->storage_samples+=v->diffuser[ch][i].length;
        }
        v->early[ch].length=(unsigned)ceil(rate*0.065)+1;
        v->storage_samples+=v->early[ch].length;
    }
    v->storage=calloc(v->storage_samples,sizeof(float));
    if(!v->storage) return false;
    volatile unsigned char *pages=(volatile unsigned char *)v->storage;
    size_t bytes=v->storage_samples*sizeof(float);
    for(size_t offset=0;offset<bytes;offset+=4096) pages[offset]=0;
    pages[bytes-1]=0;
    float *at=v->storage;
    for(int i=0;i<8;i++) { v->tank[i].data=at; at+=v->tank[i].length; }
    for(int ch=0;ch<2;ch++) {
        for(int i=0;i<4;i++) { v->diffuser[ch][i].data=at; at+=v->diffuser[ch][i].length; }
        v->early[ch].data=at; at+=v->early[ch].length;
    }
    v->dc_pole=exp(-2*M_PI*18/rate);
    return true;
}

static void reverb_reset(stereo_reverb *v) {
    for(int i=0;i<8;i++) {
        v->tank[i].cursor=v->tank[i].valid=0;
        v->damping[i]=v->dc[i]=0;
    }
    for(int ch=0;ch<2;ch++) {
        for(int i=0;i<4;i++) v->diffuser[ch][i].cursor=v->diffuser[ch][i].valid=0;
        v->early[ch].cursor=v->early[ch].valid=0;
        v->input_low[ch]=v->input_high[ch]=0;
    }
}

static void reverb_prepare(stereo_reverb *v,double x,bool ice,unsigned smoothing) {
    v->ice=ice;
    v->decay_seconds=ice ? 1.5*pow(12,x) : 0.35*pow(24,x);
    double cutoff=fmin(v->rate*0.4,ice ? 14000 : 9500);
    ramp_set(&v->tone,1-exp(-2*M_PI*cutoff/v->rate),smoothing);
    v->input_hp=exp(-2*M_PI*(ice ? 240 : 120)/v->rate);
    v->input_lp=1-exp(-2*M_PI*fmin(v->rate*0.4,ice ? 15000 : 12000)/v->rate);
    v->predelay=(unsigned)fmax(1,round(v->rate*(ice ? 0.024 : 0.012)));
    static const double early_seconds[3]={0.0071,0.0137,0.0239};
    for(int i=0;i<3;i++) v->early_taps[i]=(unsigned)fmax(1,round(v->rate*early_seconds[i]));
    for(int i=0;i<8;i++) {
        double gain=pow(10,-3.0*v->tank[i].length/(v->rate*v->decay_seconds));
        ramp_set(&v->feedback[i],gain,smoothing);
    }
}

static double reverb_read(const reverb_line *line,unsigned back) {
    if(line->valid<back) return 0;
    unsigned at=line->cursor>=back ? line->cursor-back : line->cursor+line->length-back;
    return line->data[at];
}

static void reverb_write(reverb_line *line,double value) {
    line->data[line->cursor]=(float)(fabs(value)<1e-24 ? 0 : value);
    if(++line->cursor==line->length) line->cursor=0;
    if(line->valid<line->length) line->valid++;
}

static double reverb_allpass(reverb_line *line,double input,double gain) {
    double delayed=reverb_read(line,line->length);
    double output=delayed-gain*input;
    reverb_write(line,input+gain*output);
    return output;
}

static void reverb_process(stereo_reverb *v,const double input[2],double output[2]) {
    static const double diffusion[4]={0.72,0.69,0.65,0.61};
    static const double left_sign[8]={1,1,-1,-1,1,-1,1,-1};
    static const double right_sign[8]={1,-1,1,-1,-1,-1,1,1};
    double diffused[2],early[2],delayed[8],feedback[8],injection[8];
    for(int ch=0;ch<2;ch++) {
        v->input_high[ch]=(1-v->input_hp)*input[ch]+v->input_hp*v->input_high[ch];
        double high=input[ch]-v->input_high[ch];
        v->input_low[ch]+=v->input_lp*(high-v->input_low[ch]);
        reverb_line *line=&v->early[ch];
        double predelayed=reverb_read(line,v->predelay);
        early[ch]=0;
        for(int i=0;i<3;i++) early[ch]+=reverb_read(line,v->predelay+v->early_taps[i])*(0.16-0.035*i);
        reverb_write(line,v->input_low[ch]);
        for(int i=0;i<4;i++) predelayed=reverb_allpass(&v->diffuser[ch][i],predelayed,diffusion[i]);
        diffused[ch]=predelayed;
    }
    double tone=ramp_next(&v->tone);
    for(int i=0;i<8;i++) {
        delayed[i]=reverb_read(&v->tank[i],v->tank[i].length);
        v->damping[i]+=tone*(delayed[i]-v->damping[i]);
        v->dc[i]=(1-v->dc_pole)*v->damping[i]+v->dc_pole*v->dc[i];
        double gain=ramp_next(&v->feedback[i]);
        injection[i]=sqrt(fmax(0,1-gain*gain));
        feedback[i]=(v->damping[i]-v->dc[i])*gain;
    }
    for(unsigned stride=1;stride<8;stride*=2) {
        for(unsigned base=0;base<8;base+=stride*2) {
            for(unsigned j=0;j<stride;j++) {
                double a=feedback[base+j],b=feedback[base+j+stride];
                feedback[base+j]=a+b;
                feedback[base+j+stride]=a-b;
            }
        }
    }
    double l=0,r=0;
    for(int i=0;i<8;i++) {
        double excitation=(diffused[0]*left_sign[i]+diffused[1]*right_sign[i])*0.25*injection[i];
        reverb_write(&v->tank[i],feedback[i]*0.3535533905932738+excitation);
        l+=delayed[i]*left_sign[i]; r+=delayed[i]*right_sign[i];
    }
    output[0]=l*0.25+early[0]; output[1]=r*0.25+early[1];
}

#endif
