import Foundation

public extension PipelineEngine {
    func registerSwiftScanners() {
        let swiftLint = SwiftLintScanner()
        let swiftFormat = SwiftFormatScanner()
        let buildChecker = BuildChecker()

        registerScanner(swiftLint)
        registerScanner(swiftFormat)
        registerScanner(buildChecker)
        registerFixer(swiftLint)
        registerFixer(swiftFormat)
    }

    func registerJSScanners() {
        let eslint = ESLintScanner()
        let prettier = PrettierScanner()

        registerScanner(eslint)
        registerScanner(prettier)
        registerFixer(eslint)
        registerFixer(prettier)
    }

    func registerFlutterScanners() {
        let dartAnalyzer = DartAnalyzerScanner()
        let dartFormat = DartFormatScanner()
        let flutterAnalyzer = FlutterAnalyzerScanner()

        registerScanner(dartAnalyzer)
        registerScanner(dartFormat)
        registerScanner(flutterAnalyzer)
        registerFixer(dartFormat)
    }

    func registerAllScanners() {
        registerSwiftScanners()
        registerJSScanners()
        registerFlutterScanners()
    }

    func registerAIFixer(apiKey: String, maxIssuesPerRun: Int = 20) {
        let config = LLMConfig(apiKey: apiKey)
        let aiFixer = AIFixer(llmConfig: config, maxIssuesPerRun: maxIssuesPerRun)
        registerFixer(aiFixer)
    }
}
