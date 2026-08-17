import Foundation
import TikTokBusinessGatewayShared

public struct TikTokPageInfo: Codable, Equatable, Sendable {
  public let page: Int
  public let pageSize: Int
  public let totalNumber: Int?
  public let totalPage: Int?

  enum CodingKeys: String, CodingKey {
    case page
    case pageSize = "page_size"
    case totalNumber = "total_number"
    case totalPage = "total_page"
  }
}

public struct GatewayPage<Item: Codable & Sendable>: Codable, Sendable {
  public let items: [Item]
  public let pageInfo: TikTokPageInfo
  public let endReached: Bool
  public let nextPage: Int?
  public let snapshotConsistency: String

  public init(items: [Item], pageInfo: TikTokPageInfo) throws {
    let end = try pageInfo.validatedEndReached(itemCount: items.count)
    self.items = items
    self.pageInfo = pageInfo
    self.endReached = end
    if end {
      self.nextPage = nil
    } else {
      let (nextPage, overflow) = pageInfo.page.addingReportingOverflow(1)
      guard !overflow, nextPage <= PaginationBounds.maximumPage else {
        throw GatewayError(.invalidResponse, message: "TikTok pagination exceeded safe bounds")
      }
      self.nextPage = nextPage
    }
    self.snapshotConsistency = "notGuaranteed"
  }
}

public enum PaginationBounds {
  public static let maximumPage = 1_000_000
  public static let maximumPageSize = 1_000
}

public struct PageRequest: Equatable, Sendable {
  public let page: Int
  public let pageSize: Int

  public init(page: Int = 1, pageSize: Int = 100) throws {
    guard (1...PaginationBounds.maximumPage).contains(page),
      (1...PaginationBounds.maximumPageSize).contains(pageSize)
    else {
      throw GatewayError(
        .invalidArgument,
        message:
          "Page must be 1 through \(PaginationBounds.maximumPage) and page size must be 1 through \(PaginationBounds.maximumPageSize)"
      )
    }
    self.page = page
    self.pageSize = pageSize
  }
}

public struct AuthorizedAdvertiser: Codable, Equatable, Sendable {
  public let advertiserID: String
  public let advertiserName: String?

  enum CodingKeys: String, CodingKey {
    case advertiserID = "advertiser_id"
    case advertiserName = "advertiser_name"
  }
}

public struct AdvertiserInfo: Codable, Equatable, Sendable {
  public let advertiserID: String
  public let name: String?
  public let status: String?
  public let timeZone: String?
  public let currency: String?

  enum CodingKeys: String, CodingKey {
    case advertiserID = "advertiser_id"
    case name, status, currency
    case timeZone = "timezone"
  }
}

public struct CampaignSummary: Codable, Equatable, Sendable {
  public let campaignID: String
  public let campaignName: String?
  public let operationStatus: String?
  public let secondaryStatus: String?
  public let createTime: String?
  public let modifyTime: String?

  enum CodingKeys: String, CodingKey {
    case campaignID = "campaign_id"
    case campaignName = "campaign_name"
    case operationStatus = "operation_status"
    case secondaryStatus = "secondary_status"
    case createTime = "create_time"
    case modifyTime = "modify_time"
  }
}

public struct AdGroupSummary: Codable, Equatable, Sendable {
  public let adGroupID: String
  public let campaignID: String?
  public let adGroupName: String?
  public let operationStatus: String?
  public let secondaryStatus: String?
  public let createTime: String?
  public let modifyTime: String?

  enum CodingKeys: String, CodingKey {
    case adGroupID = "adgroup_id"
    case campaignID = "campaign_id"
    case adGroupName = "adgroup_name"
    case operationStatus = "operation_status"
    case secondaryStatus = "secondary_status"
    case createTime = "create_time"
    case modifyTime = "modify_time"
  }
}

public struct AdSummary: Codable, Equatable, Sendable {
  public let adID: String
  public let adGroupID: String?
  public let campaignID: String?
  public let adName: String?
  public let operationStatus: String?
  public let secondaryStatus: String?
  public let createTime: String?
  public let modifyTime: String?

  enum CodingKeys: String, CodingKey {
    case adID = "ad_id"
    case adGroupID = "adgroup_id"
    case campaignID = "campaign_id"
    case adName = "ad_name"
    case operationStatus = "operation_status"
    case secondaryStatus = "secondary_status"
    case createTime = "create_time"
    case modifyTime = "modify_time"
  }
}

public struct ReportRow: Codable, Equatable, Sendable {
  public let dimensions: [String: JSONValue]
  public let metrics: [String: JSONValue]
}

public enum ReportDataLevel: String, Codable, Sendable {
  case advertiser = "AUCTION_ADVERTISER"
  case campaign = "AUCTION_CAMPAIGN"
  case adGroup = "AUCTION_ADGROUP"
  case ad = "AUCTION_AD"
}

public struct SynchronousReportRequest: Codable, Equatable, Sendable {
  public let advertiserID: String
  public let dataLevel: ReportDataLevel
  public let dimensions: [String]
  public let metrics: [String]
  public let startDate: String
  public let endDate: String
  public let page: Int
  public let pageSize: Int

  enum CodingKeys: String, CodingKey {
    case advertiserID = "advertiser_id"
    case dataLevel = "data_level"
    case dimensions, metrics
    case startDate = "start_date"
    case endDate = "end_date"
    case page
    case pageSize = "page_size"
  }

  public init(
    advertiserID: String,
    dataLevel: ReportDataLevel,
    dimensions: [String],
    metrics: [String],
    startDate: String,
    endDate: String,
    page: Int = 1,
    pageSize: Int = 100
  ) {
    self.advertiserID = advertiserID
    self.dataLevel = dataLevel
    self.dimensions = dimensions
    self.metrics = metrics
    self.startDate = startDate
    self.endDate = endDate
    self.page = page
    self.pageSize = pageSize
  }

  public func validate(now: Date = Date()) throws {
    try IdentifierValidator.requireCanonicalDecimal(advertiserID, name: "advertiser_id")
    guard !dimensions.isEmpty, !metrics.isEmpty,
      Set(dimensions).count == dimensions.count,
      Set(metrics).count == metrics.count,
      dimensions.allSatisfy(Self.allowedDimensions.contains),
      metrics.allSatisfy(Self.allowedMetrics.contains),
      (1...PaginationBounds.maximumPageSize).contains(pageSize),
      (1...PaginationBounds.maximumPage).contains(page)
    else {
      throw GatewayError(.invalidArgument, message: "Report fields or pagination are invalid")
    }
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    guard let start = formatter.date(from: startDate), formatter.string(from: start) == startDate,
      let end = formatter.date(from: endDate), formatter.string(from: end) == endDate,
      start <= end, end <= now,
      Calendar(identifier: .gregorian).dateComponents([.day], from: start, to: end).day.map({
        $0 <= 30
      }) == true
    else {
      throw GatewayError(
        .invalidArgument,
        message: "Report dates must be valid, non-future, ordered, and span at most 31 days")
    }
  }

  public static let allowedDimensions: Set<String> = [
    "advertiser_id", "campaign_id", "adgroup_id", "ad_id", "stat_time_day",
  ]
  public static let allowedMetrics: Set<String> = [
    "spend", "impressions", "clicks", "ctr", "cpc", "cpm", "reach",
    "conversion", "cost_per_conversion", "video_play_actions",
  ]
}

extension TikTokPageInfo {
  fileprivate func validatedEndReached(itemCount: Int) throws -> Bool {
    guard (1...PaginationBounds.maximumPage).contains(page),
      (1...PaginationBounds.maximumPageSize).contains(pageSize),
      itemCount <= pageSize,
      totalNumber.map({ $0 >= 0 }) ?? true,
      totalPage.map({ (0...PaginationBounds.maximumPage).contains($0) }) ?? true
    else {
      throw GatewayError(.invalidResponse, message: "TikTok returned invalid page metadata")
    }

    if let totalNumber {
      let additionalPage = totalNumber % pageSize == 0 ? 0 : 1
      let (calculatedTotalPage, pageCountOverflow) = (totalNumber / pageSize)
        .addingReportingOverflow(additionalPage)
      guard !pageCountOverflow, calculatedTotalPage <= PaginationBounds.maximumPage else {
        throw GatewayError(.invalidResponse, message: "TikTok totals exceeded safe bounds")
      }
      if let totalPage {
        let validEmptyTotal = totalNumber == 0 && (totalPage == 0 || totalPage == 1)
        guard validEmptyTotal || totalPage == calculatedTotalPage else {
          throw GatewayError(.invalidResponse, message: "TikTok returned contradictory totals")
        }
      }
      if totalNumber == 0 {
        guard page == 1, itemCount == 0 else {
          throw GatewayError(.invalidResponse, message: "TikTok returned inconsistent empty totals")
        }
        return true
      }

      let (startOffset, offsetOverflow) = (page - 1).multipliedReportingOverflow(by: pageSize)
      guard !offsetOverflow, startOffset < totalNumber else {
        throw GatewayError(.invalidResponse, message: "TikTok returned an out-of-range page")
      }
      let expectedItemCount = min(pageSize, totalNumber - startOffset)
      guard itemCount == expectedItemCount else {
        throw GatewayError(.invalidResponse, message: "TikTok page contents contradict totals")
      }
      let (coveredItems, coveredOverflow) = page.multipliedReportingOverflow(by: pageSize)
      guard !coveredOverflow else {
        throw GatewayError(.invalidResponse, message: "TikTok pagination exceeded safe bounds")
      }
      return coveredItems >= totalNumber
    }

    if let totalPage {
      if totalPage == 0 {
        guard page == 1, itemCount == 0 else {
          throw GatewayError(.invalidResponse, message: "TikTok returned inconsistent totals")
        }
        return true
      }
      guard page <= totalPage else {
        throw GatewayError(.invalidResponse, message: "TikTok returned an out-of-range page")
      }
      if page < totalPage, itemCount != pageSize {
        throw GatewayError(
          .invalidResponse, message: "TikTok returned a truncated intermediate page")
      }
      return page == totalPage
    }

    return itemCount < pageSize
  }
}

struct ListPayload<Item: Codable & Sendable>: Codable, Sendable {
  let list: [Item]
  let pageInfo: TikTokPageInfo

  enum CodingKeys: String, CodingKey {
    case list
    case pageInfo = "page_info"
  }
}

struct ItemsPayload<Item: Codable & Sendable>: Codable, Sendable {
  let list: [Item]
}
