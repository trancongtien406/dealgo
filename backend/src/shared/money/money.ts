export class Money {
  public readonly amount: number;
  public readonly currency: string;

  constructor(amount: number, currency = 'VND') {
    if (!Number.isFinite(amount)) {
      throw new TypeError(`Invalid money amount: ${amount}`);
    }
    this.amount = Math.round(amount);
    this.currency = currency.toUpperCase();
  }

  static fromVnd(amount: number): Money {
    return new Money(amount, 'VND');
  }

  add(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.amount + other.amount, this.currency);
  }

  subtract(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.amount - other.amount, this.currency);
  }

  format(): string {
    return `${this.amount.toLocaleString('vi-VN')} ${this.currency}`;
  }

  private assertSameCurrency(other: Money): void {
    if (this.currency !== other.currency) {
      throw new Error(`Currency mismatch: ${this.currency} vs ${other.currency}`);
    }
  }
}
