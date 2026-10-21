import { Type } from 'class-transformer';
import { IsBoolean, IsNumber, IsOptional, Max, Min } from 'class-validator';

/** DEC-PROD-031: driver position heartbeat (does not change online or service toggles). */
export class ReportLocationDto {
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat!: number;

  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lng!: number;
}

export class UpsertPresenceDto {
  @IsBoolean()
  online!: boolean;

  /** DEC-PROD-023: take ride requests while online. Omitted keeps the stored choice. */
  @IsOptional()
  @IsBoolean()
  rideEnabled?: boolean;

  /** DEC-PROD-023: take food deliveries while online. Omitted keeps the stored choice. */
  @IsOptional()
  @IsBoolean()
  foodEnabled?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  lat?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  lng?: number;
}
