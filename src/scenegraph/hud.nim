import std/strformat
import glm
import node
import ../game/resmanager
import ../game/screen
import ../gfx/color
import ../gfx/graphics
import ../gfx/recti
import ../gfx/shader
import ../gfx/spritesheet
import ../gfx/texture
import ../game/room
import ../game/verb
import ../game/prefs
import ../game/shaders

const
  NumVerbs = 9
  NumActors = 6

type
  Verb* = object
    id*: VerbId
    image*: string
    fun*: string
    text*: string 
    key*: string
    flags*: int
  VerbUiColors* = object
    sentence*: Color
    verbNormal*: Color
    verbNormalTint*: Color
    verbHighlight*: Color
    verbHighlightTint*: Color
    dialogNormal*: Color
    dialogHighlight*: Color
    inventoryFrame*: Color
    inventoryBackground*: Color
    retroNormal*: Color
    retroHighlight*: Color
  ActorSlot* = ref object of RootObj
    verbUiColors*: VerbUiColors
    verbs*: array[22, Verb]
    selectable*: bool
    actor*: Object
  Hud* = ref object of Node
    actorSlots*: array[NumActors, ActorSlot]
    act*: Object
    verbRects: array[NumVerbs, VerbRect]
    verb*: Verb
    shader: Shader
    mousePos: Vec2f
  VerbRect = object
    hud*: Hud
    index*: int

proc newHud*(): Hud =
  var hud = Hud(shader: newShader(verbVtxShader, verbFgtShader))
  result = hud
  for i in 0..<result.actorSlots.len:
    result.actorSlots[i] = ActorSlot()
  result.init()
  result.zOrder = 100
  for i in 0..<NumVerbs:
    result.verbRects[i] = VerbRect(hud: result, index: i)

proc drawSprite(sf: SpriteSheetFrame, texture: Texture, color: Color, transf: Mat4f) =
  let pos = vec3f(sf.spriteSourceSize.x.float32,  - sf.spriteSourceSize.h.float32 - sf.spriteSourceSize.y.float32 + sf.sourceSize.y.float32, 0f)
  let trsf = translate(transf, pos)
  gfxDrawSprite(sf.frame / texture.size, texture, color, trsf)

proc actorSlot*(self: Hud, actor: Object): ActorSlot =
  for slot in self.actorSlots.mitems:
    if slot.actor == actor:
      return slot

proc update*(self: Hud, pos: Vec2f) =
  self.mousePos = vec2(pos.x, ScreenHeight - pos.y)

method drawCore(self: Hud, transf: Mat4f) =
  # draw HUD background
  let gameSheet = gResMgr.spritesheet("GameSheet")
  let classic = prefs(ClassicSentence)
  let backingFrame = gameSheet.frame(if classic: "ui_backing_tall" else: "ui_backing")
  let gameTexture = gResMgr.texture(gameSheet.meta.image)
  drawSprite(backingFrame, gameTexture, rgbaf(Black, prefs(UiBackingAlpha)), transf)

  let actorSlot = self.actorSlot(self.act)
  let verbHlt = prefs(InvertVerbHighlight)
  let verbHighlight = if verbHlt: White else: actorSlot.verbUiColors.verbHighlight
  let verbColor = if verbHlt: actorSlot.verbUiColors.verbHighlight else: White

  # draw actor's verbs
  let verbSheet = gResMgr.spritesheet("VerbSheet")
  let verbTexture = gResMgr.texture(verbSheet.meta.image)
  let lang = prefs(Lang)
  let verbSuffix = if prefs(RetroVerbs): "_retro" else: ""
  
  let saveShader = gfxShader()
  gfxShader(self.shader)
  self.shader.setUniform("u_ranges", vec2(0.8f, 0.8f))
  self.shader.setUniform("u_shadowColor", actorSlot.verbUiColors.verbNormalTint)
  self.shader.setUniform("u_normalColor", actorSlot.verbUiColors.verbHighlight)
  self.shader.setUniform("u_highlightColor", actorSlot.verbUiColors.verbHighlightTint)
  for i in 1..<actorSlot.verbs.len:
    let verb = actorSlot.verbs[i]
    if verb.image.len > 0:
      let verbFrame = verbSheet.frame(fmt"{verb.image}{verbSuffix}_{lang}")
      let over = verbFrame.spriteSourceSize.contains(vec2i(self.mousePos))
      let color = if over: verbHighlight else: verbColor
      if over:
        self.verb = verb
      drawSprite(verbFrame, verbTexture, color, transf)
  gfxShader(saveShader)

proc verb*(self: ActorSlot, verbId: VerbId): Verb =
  for verb in self.verbs:
    if verb.id == verbId:
      return verb

proc `actor=`*(self: Hud, actor: Object) =
  self.act = actor

