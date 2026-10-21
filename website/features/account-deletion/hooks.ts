import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  cancelAccountDeletion,
  fetchDriverFeeBalance,
  settleDriverFees,
} from "@/features/account-deletion/api";

const feeKey = (id: string) => ["ops", "users", id, "fee-balance"] as const;

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
    },
  });
}
