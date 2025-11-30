import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"
 
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatAddress(address: string, start = 6, end = 4): string {
  if (!address) return '';
  return `${address.slice(0, start)}...${address.slice(-end)}`;
}

export function formatNumber(value: number | string, decimals = 4): string {
  if (typeof value === 'string') {
    value = parseFloat(value);
  }
  return value.toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: decimals,
  });
}

export function formatCurrency(value: number | string, currency = 'USD'): string {
  if (typeof value === 'string') {
    value = parseFloat(value);
  }
  return value.toLocaleString(undefined, {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

export function formatPercentage(value: number | string, decimals = 2): string {
  if (typeof value === 'string') {
    value = parseFloat(value);
  }
  return `${value.toFixed(decimals)}%`;
}

export function parseInputNumber(value: string): number | null {
  if (!value) return null;
  const parsed = parseFloat(value);
  return isNaN(parsed) ? null : parsed;
}
