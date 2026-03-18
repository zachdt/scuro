export class HttpError extends Error {
  constructor(
    message: string,
    public readonly status: number
  ) {
    super(message);
    this.name = "HttpError";
  }
}

export function badRequest(message: string): HttpError {
  return new HttpError(message, 400);
}

export function notFound(message: string): HttpError {
  return new HttpError(message, 404);
}
