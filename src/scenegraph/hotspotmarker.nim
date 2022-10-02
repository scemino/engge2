import glm
import node
import ../game/ids
import ../game/engine
import ../game/room
import ../game/resmanager
import ../gfx/color
import ../gfx/graphics
import ../gfx/spritesheet
import ../gfx/texture
import ../gfx/recti

type
  HotspotMarker* = ref object of Node

proc newHotspotMarker*(): HotspotMarker =
  result = HotspotMarker()
  result.zOrder = -1000
  result.init()

proc drawSprite(sf: SpriteSheetFrame, texture: Texture, color: Color, transf: Mat4f) =
  let pos = vec3f(sf.spriteSourceSize.x.float32 - sf.sourceSize.x.float32 / 2f,  - sf.spriteSourceSize.h.float32 - sf.spriteSourceSize.y.float32 + sf.sourceSize.y.float32 / 2f, 0f)
  let trsf = translate(transf, pos)
  gfxDrawSprite(sf.frame / texture.size, texture, color, trsf)

method drawCore(self: HotspotMarker, transf: Mat4f) =
  let gameSheet = gResMgr.spritesheet("GameSheet")
  let texture = gResMgr.texture(gameSheet.meta.image)
  let frame = gameSheet.frame("hotspot_marker")
  let color = rgb(255, 165, 0)
  for layer in gEngine.room.layers:
    for obj in layer.objects:
      if obj.id.isObject and obj.objType == otNone and obj.touchable:
        let pos = gEngine.room.roomToScreen(obj.node.absolutePosition())
        let t = translate(mat4(1f), vec3(pos, 0f))
        drawSprite(frame, texture, color,  t)
