#include <metal_stdlib>
using namespace metal;

// kernel void fixtureCommentedKernel(uint id [[thread_position_in_grid]]) {}

float fixtureHelper(float x) {
    return x * 2;
}

kernel void fixtureUsedKernel(device float *data [[buffer(0)]],
                              uint id [[thread_position_in_grid]])
{
    data[id] = fixtureHelper(data[id]);
}

vertex float4 fixtureSpecializedVertex(uint vid [[vertex_id]]) {
    return float4(0);
}

fragment half4
fixtureUnusedFragment(float4 position [[position]])
{
    return half4(1);
}

[[visible]]
float fixtureUnusedVisible(float x) {
    return x;
}

[[visible]] float fixtureDescriptorVisible(float x) {
    return x;
}

[[stitchable]] float fixtureUnusedStitchable(float x) {
    return x;
}

#if FIXTURE_FLAG
kernel void fixtureConditionalKernel(device float *data [[buffer(0)]]) {}
#endif
