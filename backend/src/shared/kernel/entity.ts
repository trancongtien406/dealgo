export abstract class Entity<TId = string> {
  constructor(public readonly id: TId) {}

  equals(other?: Entity<TId> | null): boolean {
    if (other === null || other === undefined) {
      return false;
    }
    if (this === other) {
      return true;
    }
    return this.id === other.id;
  }
}
