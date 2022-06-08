import ../gfx/graphics
import ../gfx/shader

type
  RoomEffect* = enum
    None,
    Sepia,
    Ega,
    Vhs,
    Ghost,
    BlackAndWhite
  
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

proc setShaderEffect*(effect: RoomEffect) =
  case effect:
  of RoomEffect.None:
    gfxResetShader()
  of RoomEffect.BlackAndWhite:
    gfxShader(newShader(vertexShader, bwShader))
  else: discard