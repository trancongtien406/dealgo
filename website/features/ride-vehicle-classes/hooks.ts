"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  clearRideVehicleClassImage,
  fetchRideVehicleClasses,
  patchRideVehicleClass,
  uploadRideVehicleClassImage,
} from "@/features/ride-vehicle-classes/api";
import type { RideVehicleClassRow } from "@/features/ride-vehicle-classes/types";

export const rideVehicleClassQueryKeys = {
  all: ["ride-vehicle-classes"] as const,
  list: () => [...rideVehicleClassQueryKeys.all, "list"] as const,
};

export function useRideVehicleClassesQuery() {
  return useQuery({
    queryKey: rideVehicleClassQueryKeys.list(),
    queryFn: fetchRideVehicleClasses,
  });
}

export function usePatchRideVehicleClassMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      code: string;
      patch: Partial<Omit<RideVehicleClassRow, "code" | "sortOrder" | "imageUrl">>;
    }) => patchRideVehicleClass(input.code, input.patch),
    onSuccess: (updated) => {
      queryClient.setQueryData(
        rideVehicleClassQueryKeys.list(),
        (previous: RideVehicleClassRow[] | undefined) => {
          if (!previous) {
            return [updated];
          }
          return previous.map((row) =>
            row.code === updated.code ? updated : row,
          );
        },
      );
    },
  });
}

function replaceRow(updated: RideVehicleClassRow) {
  return (previous: RideVehicleClassRow[] | undefined) => {
    if (!previous) {
      return [updated];
    }
    return previous.map((row) => (row.code === updated.code ? updated : row));
  };
}

export function useUploadRideVehicleClassImageMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { code: string; dataUrl: string }) =>
      uploadRideVehicleClassImage(input.code, input.dataUrl),
    onSuccess: (updated) => {
      queryClient.setQueryData(
        rideVehicleClassQueryKeys.list(),
        replaceRow(updated),
      );
    },
  });
}

export function useClearRideVehicleClassImageMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (code: string) => clearRideVehicleClassImage(code),
    onSuccess: (updated) => {
      queryClient.setQueryData(
        rideVehicleClassQueryKeys.list(),
        replaceRow(updated),
      );
    },
  });
}
