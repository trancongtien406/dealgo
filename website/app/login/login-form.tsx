"use client";

import Link from "next/link";
import { useState, type FormEvent } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import { useLoginMutation } from "@/features/session/hooks";
import { ApiError } from "@/lib/api/errors";

const focusRing =
  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink";

function loginNotice(error: unknown): string {
  if (error instanceof ApiError) {
    return error.message;
  }
  return "Không thể kết nối máy chủ. Thử lại.";
}

export function LoginForm() {
  const loginMutation = useLoginMutation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [passwordVisible, setPasswordVisible] = useState(false);

  const pending = loginMutation.isPending;
  const notice = loginMutation.isError ? loginNotice(loginMutation.error) : "";

  function submitLogin() {
    if (pending) {
      return;
    }
    loginMutation.mutate({ email, password });
  }

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    submitLogin();
  }

  return (
    <form
      onSubmit={onSubmit}
      className="space-y-4"
      aria-describedby={notice ? "login-notice" : undefined}
    >
      <div className="space-y-1.5">
        <label htmlFor="ops-email" className="text-sm font-medium text-ink">
          Email công việc
        </label>
        <input
          id="ops-email"
          type="email"
          autoComplete="username"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          className={`h-11 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink ${focusRing}`}
        />
      </div>
      <div className="space-y-1.5">
        <div className="flex items-center justify-between gap-3">
          <label
            htmlFor="ops-password"
            className="text-sm font-medium text-ink"
          >
            Mật khẩu
          </label>
          <Link
            href="/login/forgot"
            className={`text-xs font-medium text-brand ${focusRing}`}
          >
            Quên mật khẩu?
          </Link>
        </div>
        <div className="relative">
          <input
            id="ops-password"
            type={passwordVisible ? "text" : "password"}
            autoComplete="current-password"
            required
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            className={`h-11 w-full rounded-xl border border-border bg-white pr-11 pl-3 text-sm text-ink ${focusRing}`}
          />
          <button
            type="button"
            className={`absolute top-1/2 right-2 grid size-8 -translate-y-1/2 place-items-center rounded-lg text-muted ${focusRing}`}
            onClick={() => setPasswordVisible((value) => !value)}
            aria-label={passwordVisible ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
          >
            <OpsIcon
              name={passwordVisible ? "eyeOff" : "eye"}
              className="size-4"
            />
          </button>
        </div>
      </div>
      <label className="flex items-center gap-2 text-sm text-ink">
        <input
          type="checkbox"
          checked={remember}
          onChange={(event) => setRemember(event.target.checked)}
          className={`size-4 accent-brand ${focusRing}`}
        />
        Duy trì phiên trên thiết bị này
      </label>
      <button
        type="submit"
        disabled={pending}
        className={`inline-flex h-11 w-full items-center justify-center rounded-xl bg-brand px-4 text-sm font-semibold text-white disabled:opacity-60 ${focusRing}`}
      >
        {pending ? "Đang đăng nhập…" : "Đăng nhập"}
      </button>
      {process.env.NODE_ENV !== "production" ? (
        <button
          type="button"
          disabled={pending}
          onClick={() => {
            // Dev only: the password is OPS_BOOTSTRAP_PASSWORD in backend/.env (never hardcoded).
            setEmail("ops@localhost");
          }}
          className={`inline-flex h-11 w-full items-center justify-center gap-2 rounded-xl border border-dashed border-brand/40 bg-brand/5 px-4 text-sm font-medium text-brand hover:bg-brand/10 disabled:opacity-60 ${focusRing}`}
        >
          <OpsIcon name="shield" className="size-4" />
          Sử dụng tài khoản Ops mặc định (ops@localhost)
        </button>
      ) : null}

      {notice ? (
        <p
          id="login-notice"
          role="alert"
          className="rounded-xl border border-danger/30 bg-danger/5 px-3 py-2 text-sm leading-6 break-words text-ink"
        >
          {notice}
        </p>
      ) : null}
    </form>
  );
}
