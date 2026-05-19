import multer from "multer";
import path from "path";
import fs from "fs";
import { Request } from "express";

// Ensure upload directories exist
const dirs = [
    path.join(process.cwd(), "uploads/profiles"),
    path.join(process.cwd(), "uploads/products"),
    path.join(process.cwd(), "uploads/company"),
];
for (const dir of dirs) {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

const ALLOWED_MIMES = new Set(["image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp"]);
const ALLOWED_EXTENSIONS = new Set([".jpg", ".jpeg", ".png", ".gif", ".webp"]);

// Check MIME type and file extension whitelist.
// Double-extension attack (e.g. evil.php.jpg) is blocked because we only
// accept extensions that map 1:1 to image MIME types.
const fileFilter = (_req: Request, file: any, cb: any) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (!ALLOWED_EXTENSIONS.has(ext)) {
        return cb(new Error("Invalid file extension. Only JPEG, PNG, GIF, and WebP are allowed."));
    }
    if (!ALLOWED_MIMES.has(file.mimetype)) {
        return cb(new Error("Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed."));
    }
    cb(null, true);
};

// 1 MB hard cap for product images; 5 MB for avatars and logos.
const PRODUCT_LIMITS = { fileSize: 1 * 1024 * 1024 };
const DEFAULT_LIMITS = { fileSize: 5 * 1024 * 1024 };

/**
 * Validates image magic bytes after multer writes the file to disk.
 * Defends against MIME-spoofed uploads (Content-Type header forgery).
 * Returns true only for JPEG, PNG, GIF, or WebP payloads.
 */
export function validateMagicBytes(filePath: string): boolean {
    try {
        const buf = Buffer.alloc(12);
        const fd = fs.openSync(filePath, "r");
        try { fs.readSync(fd, buf, 0, 12, 0); } finally { fs.closeSync(fd); }

        // JPEG: FF D8 FF
        if (buf[0] === 0xFF && buf[1] === 0xD8 && buf[2] === 0xFF) return true;
        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47) return true;
        // GIF: 47 49 46 38 (GIF8)
        if (buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x38) return true;
        // WebP: RIFF....WEBP
        if (
            buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 &&
            buf[8] === 0x57 && buf[9] === 0x45 && buf[10] === 0x42 && buf[11] === 0x50
        ) return true;

        return false;
    } catch {
        return false;
    }
}

/**
 * Guards against path traversal when deleting old uploaded files.
 * Returns the resolved path only if it stays inside the expected directory.
 */
export function safeUploadPath(relativePath: string, expectedDir: string): string | null {
    if (!relativePath || relativePath.startsWith("http")) return null;
    const resolved = path.resolve(process.cwd(), relativePath.replace(/^\//, ""));
    const base = path.resolve(process.cwd(), expectedDir);
    return resolved.startsWith(base + path.sep) || resolved === base ? resolved : null;
}

// ── Profile / user avatars ──────────────────────────────────────
const profileStorage = multer.diskStorage({
    destination: (_req: Request, _file: any, cb: any) => cb(null, path.join(process.cwd(), "uploads/profiles")),
    filename: (_req: Request, file: any, cb: any) => {
        const suffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
        cb(null, `profile-${suffix}${path.extname(file.originalname).toLowerCase()}`);
    },
});

export const uploadProfileImage = multer({ storage: profileStorage, fileFilter, limits: DEFAULT_LIMITS });

// ── Product images ──────────────────────────────────────────────
const productStorage = multer.diskStorage({
    destination: (_req: Request, _file: any, cb: any) => cb(null, path.join(process.cwd(), "uploads/products")),
    filename: (_req: Request, file: any, cb: any) => {
        const suffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
        cb(null, `product-${suffix}${path.extname(file.originalname).toLowerCase()}`);
    },
});

export const uploadProductImage = multer({ storage: productStorage, fileFilter, limits: PRODUCT_LIMITS });

// ── Company logos ───────────────────────────────────────────────
const companyStorage = multer.diskStorage({
    destination: (_req: Request, _file: any, cb: any) => cb(null, path.join(process.cwd(), "uploads/company")),
    filename: (_req: Request, file: any, cb: any) => {
        const suffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
        cb(null, `company-${suffix}${path.extname(file.originalname).toLowerCase()}`);
    },
});

export const uploadCompanyLogo = multer({ storage: companyStorage, fileFilter, limits: DEFAULT_LIMITS });
