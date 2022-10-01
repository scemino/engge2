import glm
import ../gfx/graphics
import ../gfx/shader

type
  RoomEffect* = enum
    None          = 0,
    Sepia         = 1,
    Ega           = 2,
    Vhs           = 3,
    Ghost         = 4,
    BlackAndWhite = 5
  
const
  vertexShader = """#version 330 core
precision mediump float;
layout (location = 0) in vec2 a_position;
layout (location = 1) in vec4 a_color;
layout (location = 2) in vec2 a_texCoords;

uniform mat4 u_transform;
out vec4 v_color;
out vec2 v_texCoords;

void main() {
  gl_Position = u_transform * vec4(a_position, 0, 1);
  v_color = a_color;
  v_texCoords = a_texCoords;
}"""

  bwShader = """#version 330 core
out vec4 FragColor;
in vec2 v_texCoords;
in vec4 v_color;
uniform sampler2D u_texture;
void main()
{
  vec4 texColor = texture(u_texture, v_texCoords);
  vec4 col = v_color * texColor;
  float gray = dot(col.xyz, vec3(0.299, 0.587, 0.114));
  FragColor = vec4(gray, gray, gray, col.a);
}"""

  sepiaShader = """#version 330 core
#ifdef GL_ES
precision highp float;
#endif

out vec4 FragColor;
in vec4 v_color;
in vec2 v_texCoords;
uniform sampler2D u_texture;
uniform float sepiaFlicker;
uniform float RandomValue[5];
uniform float TimeLapse;

vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }
float snoise (vec2 v)
{
    const vec4 C = vec4(0.211324865405187,   // (3.0-sqrt(3.0))/6.0
                        0.366025403784439,   // 0.5*(sqrt(3.0)-1.0)
                        -0.577350269189626,   // -1.0 + 2.0 * C.x
                        0.024390243902439);   // 1.0 / 41.0

    // First corner
    vec2 i  = floor(v + dot(v, C.yy) );
    vec2 x0 = v -   i + dot(i, C.xx);

    // Other corners
    vec2 i1;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;

    // Permutations
    i = mod289(i); // Avoid truncation effects in permutation
    vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
                     + i.x + vec3(0.0, i1.x, 1.0 ));

    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m ;
    m = m*m ;

    // Gradients: 41 points uniformly over a line, mapped onto a diamond.
    // The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)

    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;

    // Normalise gradients implicitly by scaling m
    // Approximation of: m *= inversesqrt( a0*a0 + h*h );
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );

    // Compute final noise value at P
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}


void main(void)
{
    const float RADIUS = 0.75;
    const float SOFTNESS = 0.45;
    const float ScratchValue = 0.3;

    vec4 texColor = texture( u_texture, v_texCoords);
    vec4 col = v_color * texColor;
    float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    vec2 dist = vec2(v_texCoords.x - 0.5, v_texCoords.y - 0.5);
    vec3 sepiaColor = vec3(gray) * vec3(0.9, 0.8, 0.6);   //vec3(1.2, 1.0, 0.8);
    float len = dot(dist,dist);
    float vignette = smoothstep(RADIUS, RADIUS-SOFTNESS, len);
    //   float vignette = (1.0 - len);
    col.rgb = mix(col.rgb, sepiaColor, 0.80) * vignette * sepiaFlicker;  // Want to keep SOME of the original color, so only use 80% sepia
    //   col.rgb = vec3( vignette ) * sepiaFlicker;

    for ( int i = 0; i < 1; i ++)
    {
        if ( RandomValue[i] < ScratchValue )
        {
            // Pick a random spot to show scratches
            float dist = 1.0 / ScratchValue;
            float d = distance(v_texCoords, vec2(RandomValue[i] * dist, RandomValue[i] * dist));
            if ( d < 0.4 )
            {
                // Generate the scratch
                float xPeriod = 8.0;
                float yPeriod = 1.0;
                float pi = 3.141592;
                float phase = TimeLapse;
                float turbulence = snoise(v_texCoords * 2.5);
                float vScratch = 0.5 + (sin(((v_texCoords.x * xPeriod + v_texCoords.y * yPeriod + turbulence)) * pi + phase) * 0.5);
                vScratch = clamp((vScratch * 10000.0) + 0.35, 0.0, 1.0);

                col.rgb *= vScratch;
            }
        }
    }
    FragColor = col;
}
"""

  ghostShader = """#version 330 core
// Work in progress ghost shader.. Too over the top at the moment, it'll make you sick.

#ifdef GL_ES
precision highp float;
#endif

out vec4 FragColor;
in vec4 v_color;
in vec2 v_texCoords;
uniform sampler2D u_texture;
uniform float iGlobalTime;
uniform float iFade;
uniform float wobbleIntensity;
uniform vec3 shadows;
uniform vec3 midtones;
uniform vec3 highlights;

const float speed = 0.1;
const float emboss = 0.70;
const float intensity = 0.6;
const int steps = 4;
const float frequency = 9.0;


float colour(vec2 coord) {
    float col = 0.0;

    float timeSpeed = iGlobalTime*speed;
    vec2 adjc = coord;
    adjc.x += timeSpeed;   //adjc0.x += fcos*timeSpeed;
    float sum0 = cos( adjc.x*frequency)*intensity;
    col += sum0;

    adjc = coord;
    float fcos = 0.623489797;
    float fsin = 0.781831503;
    adjc.x += fcos*timeSpeed;
    adjc.y -= fsin*timeSpeed;
    float sum1 = cos( (adjc.x*fcos - adjc.y*fsin)*frequency)*intensity;
    col += sum1;

    adjc = coord;
    fcos = -0.900968909;
    fsin = 0.433883607;
    adjc.x += fcos*timeSpeed;
    adjc.y -= fsin*timeSpeed;
    col += cos( (adjc.x*fcos - adjc.y*fsin)*frequency)*intensity;

    // do same in reverse.
    col += sum1;
    col += sum0;

    return cos(col);
}

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float rand(vec2 Input)
{
    float dt= dot(Input, vec2(12.9898,78.233));
    float sn= mod(dt,3.14);
    return fract(sin(sn)*43758.5453123);
}

float color_balance( float col, float l, vec3 change )
{
    // NOTE: change = (shadow, midtones, highlights)

    float sup = 83.0;    // shadow upper bounds
    float mup = 166.0;    // midtones upper bounds

    float value = col*255.0;
    l = l * 100.0;

    if (l < sup)
    {
        // shadow
        float f = (sup - l + 1.0)/(sup + 1.0);
        value += change.x * f;
    }
    else if (l < mup)
    {
        // midtone
        float mrange = (mup - sup)/2.0;
        float mid = mrange + sup;
        float diff = mid - l;
        diff = -diff;
        if (diff < 0.0)
        {
            float f = 1.0 - (diff + 1.0) / (mrange + 1.0);
            value += change.y * f;
        }
    }
    else
    {
        // highlight
        float f = (l - mup + 1.0)/(255.0 - mup + 1.0);
        value += change.z * f;
    }
    value = min(255.0,max(0.0,value));
    return value/255.0;
}

vec2 rgb2cv(vec3 RGB)
{
    vec4 P = (RGB.g < RGB.b) ? vec4(RGB.bg, -1.0, 2.0/3.0) : vec4(RGB.gb, 0.0, -1.0/3.0);
    vec4 Q = (RGB.r < P.x) ? vec4(P.xyw, RGB.r) : vec4(RGB.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    return vec2(C, Q.x);
}

float rgbToLuminance(vec3 RGB)
{
    float cMax = max( max(RGB.x, RGB.y), RGB.z);
    float cMin = min( min(RGB.x, RGB.y), RGB.z);

    return (cMax+cMin) * 0.5;
}


void main(void)
{
    vec2 c1 = v_texCoords;
    float cc1 = colour(c1);
    vec2 offset;

    c1.x += (0.001 *wobbleIntensity);      // appx 12 pixels horizontal
    offset.x = emboss*(cc1-colour(c1));

    c1.x = v_texCoords.x;
    c1.y += (0.002*wobbleIntensity);      // appx 12 pixels verticle
    offset.y = emboss*(cc1-colour(c1));

    // TODO: The effect should be centered around Franklyns position in the room, not the center
    //if ( emitFromCenter == 1)
    {
        vec2 center = vec2(0.5, 0.5);
        float distToCenter = distance(center, v_texCoords);
        offset *= distToCenter * 2.0;
    }

    c1 = v_texCoords;
    c1 += ( offset * iFade );

    vec3 col = vec3(0,0,0);
    if ( c1.x >= 0.0 && c1.x < (1.0-0.003125) )
    {
        col = texture(u_texture,c1).rgb;
        float intensity = rgbToLuminance(col);  //(col.r + col.g + col.b) * 0.333333333;

        // Exponential Shadows
        float shadowsBleed = 1.0 - intensity;
        shadowsBleed *= shadowsBleed;
        shadowsBleed *= shadowsBleed;

        // Exponential midtones
        float midtonesBleed = 1.0 - abs(-1.0 + intensity * 2.0);
        midtonesBleed *= midtonesBleed;
        midtonesBleed *= midtonesBleed;

        // Exponential Hilights
        float hilightsBleed = intensity;
        hilightsBleed *= hilightsBleed;
        hilightsBleed *= hilightsBleed;

        vec3 colorization = col.rgb + shadows * shadowsBleed +
        midtones * midtonesBleed +
        highlights * hilightsBleed;

        colorization = mix(col, colorization,iFade);

        //col = lerp(col, colorization, _Amount);
        col =  min(vec3(1.0),max(vec3(0.0),colorization));
    }
    FragColor = v_color * vec4(col, texture(u_texture, c1).a);
}"""

type
  ShaderParams* = object
    effect*: RoomEffect
    sepiaFlicker: float32
    randomValue*: array[5, float32]
    timeLapse*: float32
    iGlobalTime*: float32
    iFade*: float32
    wobbleIntensity*: float32
    shadows*: Vec3f
    midtones*: Vec3f
    highlights*: Vec3f

var
  gShaderParams* = ShaderParams(sepiaFlicker: 1f, iFade: 1f, wobbleIntensity: 1f, shadows: vec3(-0.3f, 0f, 0f), midtones: vec3(-0.2f, 0f, 0.1f), highlights: vec3(0f, 0f, 0.2f))

proc setShaderEffect*(effect: RoomEffect) =
  gShaderParams.effect = effect
  case effect:
  of RoomEffect.None:
    gfxResetShader()
  of RoomEffect.Sepia:
    let shader = newShader(vertexShader, sepiaShader)
    gfxShader(shader)
    shader.setUniform("sepiaFlicker", gShaderParams.sepiaFlicker)
  of RoomEffect.BlackAndWhite:
    gfxShader(newShader(vertexShader, bwShader))
  of RoomEffect.Ghost:
    let shader = newShader(vertexShader, ghostShader)
    gfxShader(shader)
    
  else: discard

proc updateShader*() =
  if gShaderParams.effect == RoomEffect.Sepia:
    let shader = gfxShader()
    shader.setUniform("RandomValue", gShaderParams.randomValue)
    shader.setUniform("TimeLapse", gShaderParams.timeLapse)
  elif gShaderParams.effect == RoomEffect.Ghost:
    let shader = gfxShader()
    shader.setUniform("iGlobalTime", gShaderParams.iGlobalTime)
    shader.setUniform("iFade", gShaderParams.iFade)
    shader.setUniform("wobbleIntensity", gShaderParams.wobbleIntensity)
    shader.setUniform("shadows", gShaderParams.shadows)
    shader.setUniform("midtones", gShaderParams.midtones)
    shader.setUniform("highlights", gShaderParams.highlights)
    