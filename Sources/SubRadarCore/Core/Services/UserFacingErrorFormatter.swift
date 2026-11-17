import Foundation

/// 将底层系统、网络、编解码及业务异常统一转换为通俗易懂的中文提示，避免暴露英文底层报错堆栈
public enum UserFacingErrorFormatter {
    public static func message(for error: Error) -> String {
        if error is CancellationError {
            return "操作已取消。"
        }

        if let urlError = error as? URLError {
            return message(for: urlError)
        }

        if error is DecodingError {
            return "返回的数据格式与预期不一致，暂时无法解析。"
        }

        if let localized = error as? LocalizedError,
            let description = localized.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
            !description.isEmpty
        {
            return sanitizeEmbeddedTechnicalNoise(description)
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            return message(forCocoaCode: nsError.code)
        }

        if nsError.domain == NSURLErrorDomain {
            return message(for: URLError(URLError.Code(rawValue: nsError.code)))
        }

        return "操作未能完成，请检查输入信息与网络设置后重试。"
    }

    private static func message(for urlError: URLError) -> String {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return "当前似乎未连接到网络，请检查网络或代理设置后重试。"
        case .timedOut:
            return "请求超时，请检查网络连接是否畅通或稍后再试。"
        case .cannotFindHost, .dnsLookupFailed:
            return "无法解析服务器地址，请检查填写的网址或 DNS / 代理设置。"
        case .cannotConnectToHost:
            return "无法连接到目标服务器，请确认地址正确且服务正常可用。"
        case .secureConnectionFailed,
            .serverCertificateUntrusted,
            .serverCertificateHasBadDate,
            .serverCertificateNotYetValid,
            .serverCertificateHasUnknownRoot:
            return "安全连接建立失败（HTTPS 证书异常或系统时间不准确），请检查网络代理或证书设置。"
        case .unsupportedURL, .badURL:
            return "网址格式不正确，请填写以 http:// 或 https:// 开头的完整地址。"
        case .cancelled:
            return "请求已取消。"
        default:
            return "网络请求失败，请检查网络连接、代理设置或目标地址后重试。"
        }
    }

    private static func message(forCocoaCode code: Int) -> String {
        switch code {
        case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
            return "未找到指定文件，可能已被移动、重命名或删除。"
        case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
            return "没有访问该文件或目录的权限，请重新选择路径或检查系统权限设置。"
        case NSFileReadCorruptFileError:
            return "文件内容可能已损坏或编码不受支持，无法读取。"
        case NSFileWriteOutOfSpaceError:
            return "磁盘空间不足，无法写入文件。"
        default:
            return "文件读写未能完成，请检查文件状态和访问权限后重试。"
        }
    }

    private static func sanitizeEmbeddedTechnicalNoise(_ text: String) -> String {
        if text.contains("The Internet connection appears to be offline") {
            return "当前似乎未连接到网络，请检查网络设置后重试。"
        }
        if text.contains("The request timed out") {
            return "请求超时，请检查网络连接或稍后再试。"
        }
        if text.contains("Could not connect to the server") {
            return "无法连接到服务器，请确认地址与网络状态。"
        }
        return text
    }
}

extension Error {
    public var userFacingMessage: String {
        UserFacingErrorFormatter.message(for: self)
    }
}
