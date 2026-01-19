import Foundation
import FoundationModels
import HTTPTypes
import Hummingbird

enum HealthHandler {
    @available(macOS 26, *)
    static func handle() -> Response {
        let model = SystemLanguageModel.default
        let status: String
        let httpStatus: HTTPResponse.Status

        switch model.availability {
        case .available:
            status = "ok"
            httpStatus = .ok
        case .unavailable(.deviceNotEligible):
            status = "unavailable: device not eligible for Foundation Models"
            httpStatus = .serviceUnavailable
        case .unavailable(.appleIntelligenceNotEnabled):
            status = "unavailable: Apple Intelligence not enabled in Settings"
            httpStatus = .serviceUnavailable
        case .unavailable(.modelNotReady):
            status = "unavailable: model still downloading or not ready"
            httpStatus = .serviceUnavailable
        case .unavailable(let other):
            status = "unavailable: \(other)"
            httpStatus = .serviceUnavailable
        }

        return ResponseHelpers.textResponse(status, status: httpStatus)
    }
}
