import type { Principal } from "@icp-sdk/core/principal";
export interface Some<T> {
    __kind__: "Some";
    value: T;
}
export interface None {
    __kind__: "None";
}
export type Option<T> = Some<T> | None;
export class ExternalBlob {
    getBytes(): Promise<Uint8Array<ArrayBuffer>>;
    getDirectURL(): string;
    static fromURL(url: string): ExternalBlob;
    static fromBytes(blob: Uint8Array<ArrayBuffer>): ExternalBlob;
    withUploadProgress(onProgress: (percentage: number) => void): ExternalBlob;
}
export interface ReorderPortfolioItem {
    originalIndex: bigint;
    newIndex: bigint;
}
export interface PortfolioItem {
    media: ExternalBlob;
    title: string;
    createdAt: bigint;
    description: string;
    mediaType: string;
    category: string;
}
export enum UserRole {
    admin = "admin",
    user = "user",
    guest = "guest"
}
export interface backendInterface {
    _initializeAccessControlWithSecret(secret: string): Promise<void>;
    addPortfolioItem(title: string, category: string, media: ExternalBlob, mediaType: string, description: string): Promise<void>;
    assignCallerUserRole(user: Principal, role: UserRole): Promise<void>;
    deletePortfolioItem(index: bigint): Promise<void>;
    getCallerUserRole(): Promise<UserRole>;
    getPortfolioItems(): Promise<Array<PortfolioItem>>;
    invertOrderPortfolioItem(): Promise<void>;
    isCallerAdmin(): Promise<boolean>;
    movePortfolioItemToEnd(index: bigint): Promise<void>;
    reorderPortfolioItems(moves: Array<ReorderPortfolioItem>): Promise<void>;
    updatePortfolioItem(index: bigint, title: string | null, category: string | null, media: ExternalBlob | null, mediaType: string | null, description: string | null): Promise<void>;
}
