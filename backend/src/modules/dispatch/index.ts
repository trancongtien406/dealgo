export interface DriverCandidate {
  driverId: string;
  latitude: number;
  longitude: number;
  distanceMeters: number;
}

export interface DispatchOffer {
  id: string;
  jobType: 'RIDE' | 'FOOD';
  jobId: string;
  candidateDriverIds: string[];
  assignedDriverId?: string;
  expiresAt: Date;
}

export * from './dispatch-filter.js';
export * from './driver-location-query.dto.js';

