@testable import Indexer
import XCTest

final class MetalFunctionParserTest: XCTestCase {
    private func names(_ source: String) -> [String] {
        MetalFunctionParser.parse(source).functions.map(\.name)
    }

    func testReadsQualifiedFunctionsOnly() {
        let source = """
        float helper(float x) { return x; }
        kernel void compute(device float *data [[buffer(0)]]) { data[0] = helper(1); }
        vertex float4 vertexMain(uint vid [[vertex_id]]) { return float4(0); }
        fragment half4 fragmentMain(float4 p [[position]]) { return half4(1); }
        """

        XCTAssertEqual(names(source), ["compute", "vertexMain", "fragmentMain"])
    }

    func testReadsQualifierAndAttributesOnSeparateLines() {
        let source = """
        [[visible]]
        float
        visibleFunction(float x)
        {
            return x;
        }

        fragment
        half4
        shade(float4 p [[position]])
        {
            return half4(1);
        }
        """

        let functions = MetalFunctionParser.parse(source).functions
        XCTAssertEqual(functions.map(\.name), ["visibleFunction", "shade"])
        XCTAssertEqual(functions.map(\.line), [3, 10])
        XCTAssertEqual(functions.map(\.column), [1, 1])
    }

    func testReadsAttributeQualifiers() {
        let source = """
        [[stitchable]] float stitched(float x) { return x; }
        [[kernel, max_total_threads_per_threadgroup(64)]] void attributedKernel() {}
        [[mesh]] void meshMain() {}
        [[object]] void objectMain() {}
        [[intersection(triangle, triangle_data)]] bool hit() { return true; }
        """

        XCTAssertEqual(names(source), ["stitched", "attributedKernel", "meshMain", "objectMain", "hit"])
    }

    func testReadsTemplatesAndHostNames() {
        let source = """
        template <typename T>
        kernel void add(device T *data [[buffer(0)]]) {}

        template [[host_name("add_float")]] kernel void add<float>(device float *data [[buffer(0)]]);

        kernel vec<float, 4> generic(uint i [[thread_position_in_grid]]) {}
        """

        XCTAssertEqual(names(source), ["add", "add_float", "generic"])
    }

    func testSkipsCommentsAndStrings() {
        let source = """
        // kernel void lineComment() {}
        /* kernel void
           blockComment() {} */
        constant char *text = "kernel void inString() {}";
        kernel void real() {}
        """

        let functions = MetalFunctionParser.parse(source).functions
        XCTAssertEqual(functions.map(\.name), ["real"])
        XCTAssertEqual(functions.first?.line, 5)
    }

    func testFlagsFunctionsOfConditionalBlocks() {
        let source = """
        #if defined(USE_FAST_PATH)
        kernel void fast() {}
        #else
        kernel void slow() {}
        #endif
        kernel void always() {}
        #ifdef \\
            DEBUG
        kernel void debugOnly() {}
        #endif
        """

        let functions = MetalFunctionParser.parse(source).functions
        XCTAssertEqual(functions.map(\.name), ["fast", "slow", "always", "debugOnly"])
        XCTAssertEqual(functions.map(\.isConditional), [true, true, false, true])
    }

    func testFlagsMacrosThatDeclareFunctions() {
        XCTAssertTrue(MetalFunctionParser.parse("#define KERNEL(name) kernel void name()\nKERNEL(a) {}").definesFunctionsInMacros)
        XCTAssertFalse(MetalFunctionParser.parse("#define SCALE 2\nkernel void a() {}").definesFunctionsInMacros)
    }

    func testReadsAPrototypeAndItsDefinitionOnce() {
        let source = """
        [[visible]] float shared(float x);
        [[visible]] float shared(float x) { return x; }
        """

        XCTAssertEqual(names(source), ["shared"])
    }

    func testIgnoresStructMembersAndFunctionBodies() {
        let source = """
        struct VertexOut {
            float4 position [[position]];
            float2 uv;
        };
        kernel void body(device float *data [[buffer(0)]]) {
            float value = data[0] < 1 ? 0 : 1;
            data[0] = max(value, 2.0);
        }
        """

        XCTAssertEqual(names(source), ["body"])
    }
}
