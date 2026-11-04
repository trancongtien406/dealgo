import type { PublicPageLocale } from "@/features/content-cms/types";

/**
 * Google Play account-deletion resource (DEC-PROD-037 / S027).
 * Static copy, not CMS: Play reviews the live page, so it must never depend on a published CMS slug.
 * Facts mirror backend/src/modules/account-deletion (purge field list, blockers, grace days).
 */
export const ACCOUNT_DELETION_ROLES = [
  "CUSTOMER",
  "DRIVER",
  "MERCHANT",
  "OTHER",
] as const;
export type AccountDeletionRole = (typeof ACCOUNT_DELETION_ROLES)[number];

const COPY = {
  vi: {
    metaTitle: "Xoá tài khoản DealGo — Yêu cầu xoá dữ liệu",
    metaDescription:
      "Gửi yêu cầu xoá tài khoản DealGo trên web, kể cả khi đã gỡ ứng dụng. Không cần đăng nhập. Nêu rõ dữ liệu bị xoá, dữ liệu được giữ lại và thời hạn xử lý.",
    badge: "Quyền riêng tư và dữ liệu",
    title: "Xoá tài khoản DealGo",
    intro:
      "Trang này dành cho khách hàng, tài xế và cửa hàng dùng DealGo. Bạn có thể xoá tài khoản ngay trong ứng dụng, hoặc gửi yêu cầu tại đây nếu đã gỡ ứng dụng. Không cần đăng nhập để gửi yêu cầu.",
    inAppTitle: "Cách 1 — Xoá ngay trong ứng dụng",
    inAppSteps: [
      "Mở DealGo và đăng nhập tài khoản cần xoá.",
      "Vào Tài khoản → Xoá tài khoản (hoặc Bảo mật → Xoá tài khoản).",
      "Xác minh danh tính bằng passkey, mã SMS hoặc mật khẩu.",
      "Nhập XÓA và xác nhận. Ứng dụng đăng xuất mọi thiết bị ngay sau đó.",
    ],
    inAppNote:
      "Xác minh giúp tránh việc người khác xoá tài khoản của bạn. Nếu không xác minh được trong ứng dụng, hãy dùng cách 2 bên dưới.",
    webTitle: "Cách 2 — Gửi yêu cầu xoá trên web",
    webIntro:
      "Điền thông tin bên dưới. DealGo sẽ liên hệ qua số điện thoại hoặc email bạn cung cấp để xác minh chủ tài khoản trước khi xoá. Yêu cầu được lưu thành phiếu hỗ trợ và bạn nhận ngay mã phiếu.",
    form: {
      role: "Bạn là",
      roles: {
        CUSTOMER: "Khách hàng",
        DRIVER: "Tài xế",
        MERCHANT: "Cửa hàng",
        OTHER: "Khác",
      },
      contact: "Số điện thoại hoặc email đã đăng ký",
      contactHint: "Dùng đúng số/email gắn với tài khoản để DealGo đối chiếu.",
      name: "Tên trên tài khoản (không bắt buộc)",
      note: "Ghi chú thêm (không bắt buộc)",
      notePlaceholder: "Ví dụ: đã gỡ ứng dụng và đổi số điện thoại.",
      submit: "Gửi yêu cầu xoá",
      sending: "Đang gửi…",
      doneTitle: "Đã nhận yêu cầu xoá tài khoản",
      doneBody:
        "DealGo sẽ xác minh và phản hồi qua thông tin bạn đã cung cấp. Giữ mã phiếu để tra cứu.",
      code: "Mã phiếu",
      another: "Gửi yêu cầu khác",
      error: "Không gửi được yêu cầu. Vui lòng thử lại hoặc gọi hotline.",
      offline: "Mất kết nối máy chủ. Vui lòng thử lại.",
      privacy: "Thông tin bạn nhập chỉ dùng để xử lý yêu cầu xoá tài khoản.",
      invalidContact: "Vui lòng nhập số điện thoại hoặc email hợp lệ.",
    },
    dataTitle: "Dữ liệu sẽ bị xoá",
    dataItems: [
      "Họ tên, email, số điện thoại, ngày sinh, giới tính và ảnh đại diện.",
      "Mật khẩu, passkey, phiên đăng nhập, thiết bị nhận thông báo và mã xác minh.",
      "Địa chỉ đã lưu, thông báo trong ứng dụng và trạng thái online của tài xế.",
      "Hồ sơ đối tác (KYC/KYB): tài liệu xác minh và ghi chú xét duyệt.",
      "Thông tin liên hệ trên các phiếu hỗ trợ cũ.",
    ],
    keepTitle: "Dữ liệu được giữ lại",
    keepItems: [
      "Chuyến xe, đơn đồ ăn, sổ cái, thu nhập và đánh giá được giữ để đối soát, xử lý tranh chấp và tuân thủ nghĩa vụ kế toán, pháp luật.",
      "Sau khi xoá, các bản ghi này gắn với tài khoản ẩn danh “Người dùng đã xoá”, không còn tên, số điện thoại hay email của bạn.",
      "Nội dung phiếu hỗ trợ được giữ để tra soát, nhưng thông tin liên hệ bị xoá.",
    ],
    timingTitle: "Thời hạn xử lý",
    timingItems: [
      "Sau khi bạn xác nhận trong ứng dụng, tài khoản bị vô hiệu hoá ngay và mọi phiên đăng nhập bị thu hồi.",
      "Thời gian chờ trước khi ẩn danh hoá vĩnh viễn mặc định là 7 ngày (DealGo có thể chỉnh trong khoảng 0–90 ngày).",
      "Trong thời gian chờ, bạn có thể liên hệ hỗ trợ để khôi phục tài khoản.",
      "Hết thời gian chờ, hệ thống ẩn danh hoá dữ liệu và không thể khôi phục.",
    ],
    blockersTitle: "Khi nào chưa thể xoá",
    blockersItems: [
      "Đang có chuyến xe, đơn đồ ăn hoặc việc giao hàng chưa kết thúc.",
      "Cửa hàng còn đơn chưa xử lý xong.",
      "Tài xế còn công nợ COD hoặc phí nền tảng chưa tất toán.",
      "Tài khoản vận hành (Ops) do DealGo quản lý — hãy liên hệ quản trị viên.",
    ],
    cancelTitle: "Huỷ hoặc khôi phục",
    cancelBody:
      "Trong thời gian chờ, đăng nhập lại ứng dụng hoặc gửi yêu cầu tới hỗ trợ để khôi phục. Sau khi ẩn danh hoá thì không thể khôi phục.",
    contactTitle: "Cần hỗ trợ?",
    contactBody:
      "Nếu không gửi được biểu mẫu, liên hệ DealGo qua các kênh dưới đây và ghi rõ “Yêu cầu xoá tài khoản”.",
    hotline: "Hotline",
    email: "Email",
    support: "Trung tâm hỗ trợ",
    privacyLink: "Chính sách quyền riêng tư",
    termsLink: "Điều khoản sử dụng",
    regulationsLink: "Quy chế sử dụng",
    ticketPrefix:
      "Yêu cầu xoá tài khoản DealGo (gửi từ trang web /account-deletion).",
  },
  en: {
    metaTitle: "Delete your DealGo account — Data deletion request",
    metaDescription:
      "Request deletion of your DealGo account on the web, even after uninstalling the app. No sign-in required. See what data is deleted, what is kept and how long it takes.",
    badge: "Privacy and data",
    title: "Delete your DealGo account",
    intro:
      "This page is for DealGo customers, drivers and merchants. You can delete your account inside the app, or send a request here if you no longer have the app. No sign-in is required to submit a request.",
    inAppTitle: "Option 1 — Delete inside the app",
    inAppSteps: [
      "Open DealGo and sign in to the account you want to delete.",
      "Go to Account → Delete account (or Security → Delete account).",
      "Verify your identity with a passkey, SMS code or password.",
      "Type DELETE and confirm. Every device is signed out immediately.",
    ],
    inAppNote:
      "Verification stops someone else from deleting your account. If you cannot verify inside the app, use option 2 below.",
    webTitle: "Option 2 — Request deletion on the web",
    webIntro:
      "Fill in the form below. DealGo will contact you at the phone number or email you provide to confirm you own the account before deleting it. The request is stored as a support ticket and you get a ticket code right away.",
    form: {
      role: "You are",
      roles: {
        CUSTOMER: "Customer",
        DRIVER: "Driver",
        MERCHANT: "Merchant",
        OTHER: "Other",
      },
      contact: "Registered phone number or email",
      contactHint:
        "Use the number/email linked to the account so we can match it.",
      name: "Account name (optional)",
      note: "Anything else? (optional)",
      notePlaceholder:
        "For example: I uninstalled the app and changed my phone number.",
      submit: "Send deletion request",
      sending: "Sending…",
      doneTitle: "Deletion request received",
      doneBody:
        "DealGo will verify and reply through the contact details you gave. Keep the ticket code for follow-up.",
      code: "Ticket code",
      another: "Send another request",
      error: "Could not send the request. Try again or call our hotline.",
      offline: "Connection lost. Please try again.",
      privacy:
        "The details you enter are used only to process your deletion request.",
      invalidContact: "Enter a valid phone number or email.",
    },
    dataTitle: "Data that is deleted",
    dataItems: [
      "Name, email, phone number, date of birth, gender and profile photo.",
      "Password, passkeys, sessions, push tokens and verification codes.",
      "Saved addresses, in-app notifications and driver online status.",
      "Partner (KYC/KYB) records: verification documents and review notes.",
      "Contact details attached to earlier support tickets.",
    ],
    keepTitle: "Data that is kept",
    keepItems: [
      "Rides, food orders, ledger entries, earnings and ratings are kept for reconciliation, disputes and accounting or legal obligations.",
      "After deletion these records point to an anonymous “Deleted user” row with no name, phone number or email.",
      "Support ticket content is kept for auditing, with your contact details removed.",
    ],
    timingTitle: "How long it takes",
    timingItems: [
      "After you confirm in the app the account is disabled at once and every session is revoked.",
      "The waiting period before permanent anonymisation is 7 days by default (DealGo can set it between 0 and 90 days).",
      "During the waiting period you can contact support to restore the account.",
      "Once the waiting period ends the data is anonymised and cannot be restored.",
    ],
    blockersTitle: "When deletion is not possible yet",
    blockersItems: [
      "An active ride, food order or delivery is still in progress.",
      "A store still has open orders.",
      "A driver still owes cash-on-delivery or platform fees.",
      "Operations (Ops) accounts managed by DealGo — contact an administrator.",
    ],
    cancelTitle: "Cancel or restore",
    cancelBody:
      "During the waiting period, sign in to the app again or contact support to restore the account. After anonymisation it cannot be restored.",
    contactTitle: "Need help?",
    contactBody:
      "If the form does not work, contact DealGo through the channels below and mention “Account deletion request”.",
    hotline: "Hotline",
    email: "Email",
    support: "Support centre",
    privacyLink: "Privacy policy",
    termsLink: "Terms of use",
    regulationsLink: "Regulations",
    ticketPrefix:
      "DealGo account deletion request (sent from the /account-deletion web page).",
  },
} as const;

export function accountDeletionCopy(locale: PublicPageLocale) {
  return COPY[locale];
}
