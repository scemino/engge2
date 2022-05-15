import glm
import ../gfx/color
import ids

type 
  Light* = ref object of RootObj
    color*: Color
    pos*: Vec2i
    brightness*: float     ## light brightness 1.0f...100.f
    coneDirection*: float  ## cone direction 0...360.f
    coneAngle*: float      ## cone angle 0...360.f
    coneFalloff*: float    ## cone falloff 0.f...1.0f
    cutOffRadius*: float   ## cutoff raduus
    halfRadius*: float     ## cone half radius 0.0f...1.0f
    on*: bool
    id*: int

proc newLight*(): Light =
  Light(id: newLightId(), brightness: 1f, on: true)
