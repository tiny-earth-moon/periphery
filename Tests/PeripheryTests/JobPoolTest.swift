import Foundation
@testable import Shared
import XCTest

final class JobPoolTest: XCTestCase {
    private struct JobError: Error, Equatable {
        let job: Int
    }

    private let jobs = Array(0 ..< 2000)

    func testForEachThrowsOneOfTheConcurrentErrors() {
        let pool = JobPool(jobs: jobs)

        XCTAssertThrowsError(try pool.forEach { job in throw JobError(job: job) }) { error in
            XCTAssertTrue(isJobError(error))
        }
    }

    func testThrowingFlatMapThrowsOneOfTheConcurrentErrors() {
        let pool = JobPool(jobs: jobs)

        XCTAssertThrowsError(try pool.flatMap { (job: Int) throws -> [Int] in throw JobError(job: job) }) { error in
            XCTAssertTrue(isJobError(error))
        }
    }

    func testForEachPropagatesTheErrorOfASingleFailingJob() {
        let pool = JobPool(jobs: jobs)
        let failingJob = 1234

        XCTAssertThrowsError(try pool.forEach { job in
            if job == failingJob {
                throw JobError(job: job)
            }
        }) { error in
            XCTAssertEqual(error as? JobError, JobError(job: failingJob))
        }
    }

    func testThrowingFlatMapPropagatesTheErrorOfASingleFailingJob() {
        let pool = JobPool(jobs: jobs)
        let failingJob = 1234

        XCTAssertThrowsError(try pool.flatMap { (job: Int) throws -> [Int] in
            if job == failingJob {
                throw JobError(job: job)
            }
            return [job]
        }) { error in
            XCTAssertEqual(error as? JobError, JobError(job: failingJob))
        }
    }

    func testThrowingFlatMapReturnsEveryResultWithoutErrors() throws {
        let pool = JobPool(jobs: jobs)

        let results = try pool.flatMap { (job: Int) throws -> [Int] in [job] }

        XCTAssertEqual(results.sorted(), jobs)
    }

    // MARK: - Private

    private func isJobError(_ error: Error) -> Bool {
        guard let jobError = error as? JobError else { return false }

        return jobs.contains(jobError.job)
    }
}
