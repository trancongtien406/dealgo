"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { login, logout } from "@/features/session/api";
import type { LoginInput } from "@/features/session/types";

export function useLoginMutation() {
  const router = useRouter();
  return useMutation({
    mutationFn: (input: LoginInput) => login(input),
    onSuccess: () => {
      router.push("/overview");
      router.refresh();
    },
  });
}

export function useLogoutMutation() {
  const router = useRouter();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => logout(),
    // Always leave the private shell after a logout attempt so a failed
    // DELETE cannot leave cookies cleared while the UI stays authenticated.
    onSettled: () => {
      queryClient.clear();
      router.push("/login");
      router.refresh();
    },
  });
}
