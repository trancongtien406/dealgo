import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  cancelAccountDeletion,
  fetchDriverBalance,
  fetchDriverFeeBalance,
  recordDriverPayment,
  settleDriverFees,
} from "@/features/account-deletion/api";

const feeKey = (id: string) => ["ops", "users", id, "fee-balance"] as const;
const balanceKey = (id: string) => ["ops", "users", id, "driver-balance"] as const;

/** Restore during the grace period; refreshes every customer/driver query. */
export function useCancelAccountDeletionMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { id: string; reason: string }) =>
      cancelAccountDeletion(input.id, input.reason),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["ops"] });
    },
  });
}

export function useDriverFeeBalanceQuery(id: string) {
  return useQuery({
    queryKey: feeKey(id),
    queryFn: () => fetchDriverFeeBalance(id),
    enabled: Boolean(id),
  });
}

export function useSettleDriverFeesMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { id: string; reason: string }) =>
      settleDriverFees(input.id, input.reason),
    onSuccess: (_data, input) => {
      void queryClient.invalidateQueries({ queryKey: feeKey(input.id) });
      void queryClient.invalidateQueries({ queryKey: balanceKey(input.id) });
    },
  });
}

/** Partial payment / top-up / payout; refreshes the balance card. */
export function useDriverPaymentMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      id: string;
      direction: "DRIVER_PAID" | "DEALGO_PAID";
      amountVnd: number;
      reason: string;
    }) => recordDriverPayment(input.id, input),
    onSuccess: (_data, input) => {
      void queryClient.invalidateQueries({ queryKey: feeKey(input.id) });
      void queryClient.invalidateQueries({ queryKey: balanceKey(input.id) });
    },
  });
}

/** Balance breakdown + debt limit + ledger (settlements.read). */
export function useDriverBalanceQuery(id: string) {
  return useQuery({
    queryKey: balanceKey(id),
    queryFn: () => fetchDriverBalance(id),
    enabled: Boolean(id),
  });
}
