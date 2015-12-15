// Built by Xiao Lu
// 12/13/2015
// The final project for Cooking With Sounds
// Part II


//no. of channels   ( set 6 for performence and 2 for normal computers or earphones )
2 => int CHANNELS;

// offset
0 => int CHAN_OFFSET;

//DEADZONE
0.0005 => float DEADZONE;

// global
36 => float PITCH_OFFSET; // Key

// define the steps
2 => int W;
1 =>int H;

// which joystick
0 => int device;

// duration
200::ms => dur T;

// define a flag no.
0 => int flag;



// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// HID objects
Hid trak;
HidMsg msg;


// noise generator, biquad filter, dac (audio output) 
Noise noise => BiQuad f =>NRev WindRev=>Gain nGain=> dac;//=>dac
// set biquad pole radius
.99 => f.prad;
// set biquad gain
.001 => f.gain;
// set equal zeros 
1 => f.eqzs;
//reverb for wind
.4=>WindRev.mix;


// open joystick 0, exit on fail
if( !trak.openJoystick( device ) ) me.exit();
//print
<<< "joystick '" + trak.name() + "' ready", "" >>>;

// data structure for gametrak
class GameTrak
{
    // timestamps
    time lastTime;
    time currTime;
    
    // previous axis data
    float lastAxis[6];
    // current axis data
    float axis[6];
    // is the button down? 1 for down, 0 for up
    int buttonDown;
    
}

// gametrack
GameTrak gt;


// synthesis
ModalBar fish[CHANNELS];
NRev rev[CHANNELS];

// loop
for( int i; i < CHANNELS; i++ )
{
    fish[i] => rev[i] => dac.chan(i+CHAN_OFFSET);
    1.0 => rev[i].gain;
    0.10 => rev[i].mix; // .02
}

//Noise noise => BiQuad bq =>Gain g => dac;
//.5=> g.gain;



// counter
int n;

// spork control
spork ~ gametrak();
// print
spork ~ print();
//spork wind sound
spork ~ wind();

//spork the function of alternating scales
spork ~ changeScale();

//Pentatonic Scale
[0, 2, 4, 7, 9, 12, 14, 16,  19, 21, 24, 26, 28, 31, 33, 36, 38, 40, 43, 45, 48] @=>int scale[];//4 octaves with 21 diff notes in Pentatonic scale.


//Blues Scale - not appropriate
//<<<"blues scale">>>;
//[0, 2,4,5,6,9,11, 14, 16, 17, 18, 21, 23, 26,28,29,30,33,35,38] @=>int scale[];


// main loop
while( true )
{
    
    //set pitch and map the axis position to the pentatonic tones.. (R-Y)
    Math.round((gt.axis[4]+1)*10)$int * 20/20 => int note; 
    scale[note] + PITCH_OFFSET => float pitch;
    <<<note>>>;
    
    // set freq.
    pitch => Std.mtof => fish[n].freq;
    
    //define the speed
    Math.fabs(gt.axis[4]-gt.lastAxis[4]) * 800  => float speed;  // 800
    
    // gain (R-Z) 
    if (gt.axis[5] <= 0.30 ){ 0 => gt.axis[5];}
    else if (gt.axis[5] >= 0.40 ){ 0 => gt.axis[5];}
    else {12.0 => fish[n].noteOn; }
    
    // reverb mix (R-X) 
    //for( int i; i < CHANNELS; i++ ){
    //  gt.axis[3]/2 +0.1 => rev[i].mix;
    // }
    
    // stick hardness (L-X)
    //Math.fabs(gt.axis[1]) => fish[n].stickHardness;
    
    // strike position(L-Y)
    //Math.fabs(gt.axis[1]) => fish[n].strikePosition;
    
    // Loudness (L-Z)
    
    
    // Pitch (R-Y)
    if ( speed >= 5.0 ) {5.0 => speed;} 
    T - Math.log2(speed/5+1)*(T/ms-25)::ms => now;//the faster the swiping, the faster the sound goes
    <<< "speed: ", speed>>>;
    if ( gt.axis[0] >= 0.75 ) { 1000::ms => now; }//hold the left stick to right to keep the last sound alone(don't actually know how to express this...)
    n++;
    CHANNELS %=> n;
    
    // Note: L: axis0-x, axis1-y, axis2-z
    //               R: axis3-x, axis4-y, axis5-z
}




fun void wind()
{
    while( true ){
        // sweep the filter resonant frequency
        100.0 + Std.fabs(Math.sin((gt.axis[1]+1)/2)) * 10000.0 => f.pfreq;
        //100.0 + Std.fabs(Math.sin(gt.axis[2])) * 10000.0 => f.pfreq;
        
        if (gt.axis[2] <= 0.40 ){ 0.0 => nGain.gain;}
        0.01 + gt.axis[2]*1.5 => nGain.gain;
        
        10::ms => now;
    }
}

// print
fun void print()
{
    // time loop
    while( true )
    {
        // values
        <<< "axes:", gt.axis[0],gt.axis[1],gt.axis[2], gt.axis[3],gt.axis[4],gt.axis[5] >>>;
        // advance time
        500::ms => now;
    }
}


// gametrack handling
fun void gametrak()
{
    while( true )
    {
        // wait on HidIn as event
        trak => now;
        
        // messages received
        while( trak.recv( msg ) )
        {
            // joystick axis motion
            if( msg.isAxisMotion() )
            {            
                // check which
                if( msg.which >= 0 && msg.which < 6 )
                {
                    // check if fresh
                    if( now > gt.currTime )
                    {
                        // time stamp
                        gt.currTime => gt.lastTime;
                        // set
                        now => gt.currTime;
                    }
                    // save last
                    gt.axis[msg.which] => gt.lastAxis[msg.which];
                    // the z axes map to [0,1], others map to [-1,1]
                    if( msg.which != 2 && msg.which != 5 )
                    { msg.axisPosition => gt.axis[msg.which]; }
                    else
                    {
                        1 - ((msg.axisPosition + 1) / 2) - DEADZONE => gt.axis[msg.which];
                        if( gt.axis[msg.which] < 0 ) 0 => gt.axis[msg.which];
                    }
                }
            }
            
            // joystick button down
            else if( msg.isButtonDown() )//
            {
                <<< "button", msg.which, "down" >>>;
                
                flag++;
                if (flag >= 12){ 0 => flag; }
                <<<"Flag:", flag>>>;
                //spork the rain&thunder sounds when button down
                // spork ~ rainNthunder();
            }
            
            // joystick button up
            else if( msg.isButtonUp() )//
            {
                <<< "button", msg.which, "up" >>>;
            }
        }
    }
}

fun void changeScale()
{
    while( true )
    {
        if (flag == 0)
        {
            36 => PITCH_OFFSET; // C
            [0, 2, 3, 5, 7, 10, 12, 14, 15, 17, 19, 22, 24, 26, 27, 29, 31, 34, 36, 38, 39] @=>scale;
            <<<"Cm7">>>;
            <<<"Back to the 1st chord">>>;
            
        }
        
        if (flag == 1)
        {   
            41 => PITCH_OFFSET; // F
            <<<"Fm7">>>;
            [0, 2, 3, 5, 7, 10, 12, 14, 15, 17, 19, 22, 24, 26, 27, 29, 31, 34, 36, 38, 39] @=>scale;
        }
        
        if (flag == 2)
        {   
            38 => PITCH_OFFSET; // D
            <<<"Dm7b5">>>;
            [0, 3, 5, 6, 8, 10, 12, 15, 17, 18, 20, 22, 24, 27, 29, 30, 32, 34, 36, 39, 41] @=> scale;//
        }
        
        if (flag == 3)
        {   
            43 => PITCH_OFFSET; // G
            <<<"G7b9">>>;
            [0, 1, 3, 4, 6, 7, 9, 10, 12, 13, 15, 16, 18, 19, 21, 22, 24, 25, 27, 28, 30] @=> scale;//
        }
    
       if (flag == 4)
       {   
            36 => PITCH_OFFSET; // C
            [0, 2, 3, 5, 7, 10, 12, 14, 15, 17, 19, 22, 24, 26, 27, 29, 31, 34, 36, 38, 39] @=>scale;
            <<<"Cm7">>>;
       }
       if (flag == 5)
       {   
           39 => PITCH_OFFSET; // Eb
           [0, 2, 3, 5, 7, 10, 12, 14, 15, 17, 19, 22, 24, 26, 27, 29, 31, 34, 36, 38, 39] @=>scale;
           <<<"Ebm7">>>;
       }
       
       if (flag == 6)
       {   
           33 => PITCH_OFFSET; // Ab
           [0, 2, 4, 7, 9, 10, 12, 14, 16, 19, 21, 22, 24, 26, 28, 31, 33, 34, 36, 38, 40] @=>scale;
           <<<"Ab7">>>;
       }
       
       if (flag == 7)
       {   
           37 => PITCH_OFFSET; // Db
           [0, 2, 4, 7, 9, 11, 12, 14, 16, 19, 21, 23, 24, 26, 28, 31, 33, 35, 36, 38, 40] @=>scale;
           <<<"Dbmaj7">>>;
       }
       if (flag == 8)
       {   
           38 => PITCH_OFFSET; // D
           <<<"Dm7b5">>>;
           [0, 3, 5, 6, 8, 10, 12, 15, 17, 18, 20, 22, 24, 27, 29, 30, 32, 34, 36, 39, 41] @=> scale;//
       }
       
       if (flag == 9)
       {   
            43 => PITCH_OFFSET; // G
            <<<"G7b9">>>;
            [0, 1, 3, 4, 6, 7, 9, 10, 12, 13, 15, 16, 18, 19, 21, 22, 24, 25, 27, 28, 30] @=> scale;//
      }
       
       if (flag == 10)
       {   
           36 => PITCH_OFFSET; // C
           [0, 2, 3, 5, 7, 10, 12, 14, 15, 17, 19, 22, 24, 26, 27, 29, 31, 34, 36, 38, 39] @=>scale;
           <<<"Cm7">>>;
       }
       if (flag == 11)
       {   
            43 => PITCH_OFFSET; // G
            <<<"G7b9">>>;
            [0, 1, 3, 4, 6, 7, 9, 10, 12, 13, 15, 16, 18, 19, 21, 22, 24, 25, 27, 28, 30] @=> scale;//
       }
    
    200::ms => now;
}
}

