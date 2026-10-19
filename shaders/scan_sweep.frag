#version 460 core

// A neon line sweeping down a photo while the dish is being recognized,
// with a fading trail and a faint grid lit behind it.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;      // painted area, logical pixels
uniform float uProgress; // 0..1 along one sweep
uniform vec4 uLine;      // line colour (theme primary), straight alpha
uniform vec4 uTrail;     // trail colour (theme secondary), straight alpha

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  // Starts and ends just outside the photo, so the line enters and leaves.
  float y = uProgress * 1.2 - 0.1;
  float d = uv.y - y;

  float line = exp(-pow(d * 90.0, 2.0));
  // The trail sits above the line, which moves down.
  float trail = d < 0.0 ? exp(d * 9.0) * 0.35 : 0.0;
  vec2 cell = abs(fract(uv * vec2(14.0, 10.0)) - 0.5);
  float grid = step(0.46, max(cell.x, cell.y)) * trail * 0.5;

  float alpha = clamp(line + trail * 0.6 + grid, 0.0, 1.0);
  vec3 colour = mix(uTrail.rgb, uLine.rgb, clamp(line * 1.5, 0.0, 1.0));
  // Flutter expects premultiplied alpha.
  fragColor = vec4(colour * alpha, alpha);
}
