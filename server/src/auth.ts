/** Resolves a bearer token to a user id, or throws. */
export interface TokenVerifier {
  verify(token: string): Promise<{ uid: string }>;
}

export class AuthError extends Error {}

/** Firebase Auth ID tokens (Google / Apple sign-in on the device). */
export class FirebaseVerifier implements TokenVerifier {
  private readonly auth: { verifyIdToken(t: string): Promise<{ uid: string }> };

  constructor(auth: { verifyIdToken(t: string): Promise<{ uid: string }> }) {
    this.auth = auth;
  }

  async verify(token: string): Promise<{ uid: string }> {
    try {
      const decoded = await this.auth.verifyIdToken(token);
      return { uid: decoded.uid };
    } catch {
      throw new AuthError('invalid token');
    }
  }
}

/** Local development only: `dev:<uid>`. Refused in production by config. */
export class DevVerifier implements TokenVerifier {
  async verify(token: string): Promise<{ uid: string }> {
    const m = /^dev:([A-Za-z0-9_-]{1,64})$/.exec(token);
    if (!m) throw new AuthError('invalid dev token');
    return { uid: m[1] };
  }
}
