#version 460 core
#include <flutter/runtime_effect.glsl>

// Lens material adapted from design-systems / internal/renderer.js (MIT).
// Copyright (c) 2026 DayDreamInAReverie. See THIRD_PARTY_NOTICES.md.
// Flutter supplies these first two uniforms when used as an ImageFilter.
uniform vec2 uTextureSize;
uniform sampler2D uBackdrop;
uniform vec2 uPanelSize;
// TL, TR, BR, BL radii, in logical pixels.
uniform vec4 uRadii;
uniform float uRefraction;
uniform float uDispersion;
uniform vec2 uPointer;
uniform float uPressure;
uniform float uHover;
uniform float uLighting;

out vec4 fragColor;

float roundedDistance(vec2 p) {
  float radius = p.x < 0.0
      ? (p.y < 0.0 ? uRadii.x : uRadii.w)
      : (p.y < 0.0 ? uRadii.y : uRadii.z);
  vec2 q = abs(p) - uPanelSize * 0.5 + radius;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

vec4 sampleBackdrop(vec2 uv) {
  // Prevent seams at the texture boundary and account for the GLES orientation.
  vec2 inset = 0.5 / uTextureSize;
  uv = clamp(uv, inset, vec2(1.0) - inset);
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uBackdrop, uv);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uTextureSize;
  vec2 b = uPanelSize * 0.5;
  vec2 p = (uv - 0.5) * uPanelSize;
  float d = roundedDistance(p);
  vec2 n2 = vec2(
    roundedDistance(p + vec2(0.7, 0.0)) - roundedDistance(p - vec2(0.7, 0.0)),
    roundedDistance(p + vec2(0.0, 0.7)) - roundedDistance(p - vec2(0.0, 0.7))
  );
  n2 /= max(length(n2), 0.0001);
  float bevel = max(min(min(b.x, b.y) * 0.48, 19.0), 0.5);
  float edge = clamp(1.0 + d / bevel, 0.0, 1.0);
  float slope = pow(edge, 1.65) * 0.94;
  vec2 faceNormal = clamp(p / max(b, vec2(1.0)), -1.0, 1.0) * 0.045 * (1.0 - edge);
  vec2 normalXY = n2 * slope + faceNormal;
  vec3 normal = vec3(normalXY, sqrt(max(1.0 - dot(normalXY, normalXY), 0.001)));
  // Snell: air (1.0) -> glass (1.45), instead of a linear rim displacement.
  vec3 ray = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / 1.45);
  // Bound the optical thickness for our narrow timetable slots and tiny buttons.
  float thickness = min(18.0 + uRefraction * 57.0, min(b.x, b.y) * 1.1);
  thickness *= 1.0 + uPressure * 0.13;
  vec2 offset = ray.xy / max(-ray.z, 0.05) * thickness * uRefraction;
  offset -= p * 0.016 * uRefraction;
  vec2 at = uv + offset / uPanelSize;
  vec2 split = n2 * pow(edge, 2.8) * uDispersion * 2.6 / uPanelSize;
  vec4 center = sampleBackdrop(at);
  // Retain the frosted green channel; add only an 80% chromatic edge correction.
  vec3 rgb = center.rgb;
  rgb.r += (sampleBackdrop(at + split).r - center.r) * 0.8;
  rgb.b += (sampleBackdrop(at - split).b - center.b) * 0.8;

  if (uLighting > 0.0 && center.a > 0.0001) {
    vec3 c = rgb / center.a;
    float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(luma), c, 1.035);
    vec2 pointer = uPointer * b;
    vec2 lightVector = pointer + vec2(-80.0, -150.0);
    vec2 light = lightVector / max(length(lightVector), 0.0001);
    float directional = pow(max(dot(n2, light), 0.0), 7.0);
    float opposite = pow(max(dot(n2, -light), 0.0), 7.0) * 0.52;
    float fresnel = 0.04 + 0.96 * pow(1.0 - normal.z, 5.0);
    float outline = 1.0 - smoothstep(0.12, 1.1, abs(d + 0.65));
    float spec = (directional + opposite) * pow(edge, 4.0) * 0.065;
    spec += outline * (0.018 + directional * 0.35 + opposite * 0.15);
    spec += fresnel * 0.035;
    vec4 environmentSample = sampleBackdrop(uv + n2 * 34.0 / uPanelSize);
    vec3 environment = environmentSample.rgb / max(environmentSample.a, 0.0001);
    c = mix(c, environment, fresnel * 0.12);
    c += mix(vec3(1.0), environment, 0.18) * spec;
    float caustic = exp(-pow((d + 3.0) / 1.65, 2.0));
    c += caustic * opposite * 0.038;
    float glint = exp(-length((p - pointer) / vec2(180.0, 150.0)) * 2.0);
    c += glint * 0.024 * (0.4 + uHover);
    vec2 face = p / max(b, vec2(1.0));
    float broad = exp(-pow((face.x * 0.55 + face.y * 0.8 - light.x * 0.4) * 1.6, 2.0));
    vec4 ambientSample = sampleBackdrop(vec2(0.2, 0.225));
    vec3 ambient = ambientSample.rgb / max(ambientSample.a, 0.0001);
    c = mix(c, clamp(ambient + 0.15, 0.0, 1.0), broad * (0.045 + uPressure * 0.035));
    c -= pow(edge, 8.0) * max(dot(n2, vec2(0.45, 0.89)), 0.0) * 0.085;
    rgb = mix(rgb, clamp(c, 0.0, 1.0) * center.a, uLighting);
  }
  // Preserve premultiplied alpha, including on transparent backdrops.
  rgb = clamp(rgb, vec3(0.0), vec3(center.a));
  fragColor = vec4(rgb, center.a);
}
