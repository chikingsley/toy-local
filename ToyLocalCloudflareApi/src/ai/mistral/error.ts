export class MistralApiError extends Error {
  readonly body: unknown;
  readonly status: number;

  constructor(message: string, input: { body: unknown; status: number }) {
    super(message);
    this.name = "MistralApiError";
    this.body = input.body;
    this.status = input.status;
  }
}
