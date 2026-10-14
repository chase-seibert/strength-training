#include <metal_stdlib>
using namespace metal;

struct ConfettiVertex {
  float4 position [[position]];
  float4 color;
};

static float confettiRandom(uint seed) {
  seed ^= seed >> 16;
  seed *= 0x7feb352du;
  seed ^= seed >> 15;
  seed *= 0x846ca68bu;
  seed ^= seed >> 16;
  return float(seed & 0x00ffffffu) / float(0x01000000u);
}

vertex ConfettiVertex workoutConfettiVertex(
  uint vertexID [[vertex_id]], uint particleID [[instance_id]],
  constant float4 &uniforms [[buffer(0)]]) {
  const float2 corners[] = {
    float2(-1, -1), float2(1, -1), float2(-1, 1),
    float2(-1, 1), float2(1, -1), float2(1, 1)
  };
  const float3 palette[] = {
    float3(1.0, 0.35, 0.27), float3(0.33, 0.78, 0.65),
    float3(0.35, 0.66, 0.98), float3(1.0, 0.81, 0.28),
    float3(0.84, 0.57, 1.0)
  };
  uint seed = particleID * 17 + 1;
  float delay = confettiRandom(seed + 1) * 0.45;
  float time = max(0.0, uniforms.z - delay);
  float direction = particleID % 2 == 0 ? 1.0 : -1.0;
  float2 origin = float2(direction > 0 ? -12.0 : uniforms.x + 12.0, uniforms.y * 0.20);
  float2 velocity = float2(
    direction * (80.0 + confettiRandom(seed + 2) * 210.0),
    -110.0 - confettiRandom(seed + 3) * 240.0);
  float2 center = origin + velocity * time + float2(
    sin(time * 4.0 + confettiRandom(seed + 4) * 6.28) * 18.0,
    0.5 * (240.0 + confettiRandom(seed + 5) * 150.0) * time * time);
  float angle = confettiRandom(seed + 6) * 6.28 + time * (2.0 + confettiRandom(seed + 7) * 8.0);
  float2 size = float2(3.0 + confettiRandom(seed + 8) * 3.0, 2.0 + confettiRandom(seed + 9) * 2.0);
  float2 local = corners[vertexID] * size;
  local.x *= 0.35 + 0.65 * abs(cos(time * 6.0 + float(particleID)));
  float2 rotated = float2(
    local.x * cos(angle) - local.y * sin(angle),
    local.x * sin(angle) + local.y * cos(angle));
  float2 point = (center + rotated) / uniforms.xy;
  float alpha = uniforms.z < delay ? 0.0 : (1.0 - smoothstep(3.4, 5.0, uniforms.z)) * 0.90;
  ConfettiVertex result;
  result.position = float4(point.x * 2.0 - 1.0, 1.0 - point.y * 2.0, 0, 1);
  result.color = float4(palette[particleID % 5] * alpha, alpha);
  return result;
}

fragment float4 workoutConfettiFragment(ConfettiVertex in [[stage_in]]) {
  return in.color;
}
