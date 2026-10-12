# AGENT_RESULT — Hợp đồng bàn giao và bằng chứng

Một kết quả phải phân biệt **đã sửa code** với **đã được kiểm chứng**. Nếu dùng structured output, chuyển các trường logic sau sang JSON của runtime/host. `VERIFIED` chỉ có nghĩa là kiểm chứng tương ứng phạm vi đã ghi, không bảo đảm toàn bộ hệ thống không lỗi.

```yaml
task_id: "PROJECT-FEATURE-001"
agent: "backend-developer"
status: "IMPLEMENTED" # IMPLEMENTED | VERIFIED | PARTIAL | BLOCKED | FAILED
files_changed:
  - "relative/path"
behavior_implemented:
  - "Hành vi thực tế đã thay đổi"
acceptance_coverage:
  AC1: "IMPLEMENTED; evidence: tests/foo.test.ts::caseA"
  AC2: "NOT_VERIFIED; reason: thiếu DB cô lập"
tests:
  - command: "npm test -- foo.test.ts"
    result: "PASS" # PASS | FAIL | NOT_RUN | BLOCKED
    exit_code: 0 # chỉ có khi đã quan sát thật
    details: "14 passed on verified environment"
risks:
  - "Chưa chạy E2E trên thiết bị thật"
blockers: []
assumptions: []
commit_or_branch: "<nếu thực sự được tạo>"
requested_followup: "test-automator | code-reviewer | debugger | none"
```

## Bằng chứng tối thiểu

- Mọi command ghi **lệnh thật, trạng thái thật**, nếu chạy có exit code và môi trường phù hợp.
- Kết quả cuối nêu AC nào pass/fail/not-run/blocked; liệt kê file thay đổi từ diff thật.
- Đối với review: thêm `REVIEW_RESULT` có `finding` gồm mức P0–P3, `file:line`, điều kiện gây lỗi, ảnh hưởng, bằng chứng và quyết định `APPROVE | REQUEST_CHANGES | COMMENT | NEEDS_VERIFICATION | BLOCKED`.
- Đối với debug: thêm `DEBUG_REPORT` với `symptom`, `reproduction`, `hypotheses`, `root_cause_status: ROOT_CAUSE_CONFIRMED | ROOT_CAUSE_LIKELY | INCONCLUSIVE`, `fix`, `verification`, `regression_risk`.

## Quy tắc chốt

- Không biến `NOT_RUN` thành `PASS`.
- Không chốt `DONE` khi còn P0/P1 chưa xử lý, thiếu approval bắt buộc hoặc rủi ro dữ liệu chưa kiểm soát.
- Nếu không có review độc lập, báo `INDEPENDENT_REVIEW_NOT_PERFORMED` — không giả mạo kết quả của Code Reviewer.
- Output của agent chỉ là đề xuất/bằng chứng để Orchestrator xác minh, không thay thế kiểm tra source, test output hay CI thực tế.
