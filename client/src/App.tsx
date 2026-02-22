import { useEffect, useState } from "react";
import { authenticatedGet } from "./auth";

type UserDetails = {
  sub: string;
  name: string;
  email: string;
  issuer: string;
  audience: string;
  roles: string;
  context_title: string;
};

type LoadState =
  | { kind: "loading" }
  | { kind: "error"; message: string }
  | { kind: "ready"; user: UserDetails };

export function App() {
  const [state, setState] = useState<LoadState>({ kind: "loading" });

  useEffect(() => {
    const controller = new AbortController();
    let accessToken = "";

    async function loadUserDetails() {
      try {
        const result = await authenticatedGet(
          "/api/me",
          accessToken,
          controller.signal,
        );
        accessToken = result.accessToken;

        if (result.kind === "unauthorized") {
          throw new Error("You are not authenticated for this client session.");
        }

        const response = result.response;
        if (!response.ok) {
          throw new Error(
            `Request failed with status ${response.status}`,
          );
        }

        const user = (await response.json()) as UserDetails;
        setState({ kind: "ready", user });
      } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") {
          return;
        }

        const message =
          error instanceof Error ? error.message : "Unknown request error";
        setState({ kind: "error", message });
      }
    }

    void loadUserDetails();

    return () => {
      controller.abort();
    };
  }, []);

  return (
    <main className="mx-auto max-w-3xl px-4 py-8">
      <section className="rounded-lg border border-gray-300 bg-white p-6 shadow-sm">
        <h2 className="text-xl font-semibold text-gray-900">User Details</h2>

        {state.kind === "loading" ? (
          <p className="mt-6 text-sm text-gray-600">Loading user details...</p>
        ) : null}

        {state.kind === "error" ? (
          <p className="mt-6 rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            {state.message}
          </p>
        ) : null}

        {state.kind === "ready" ? (
          <dl className="mt-6 grid gap-3 text-sm">
            <Detail label="User ID" value={state.user.sub} />
            <Detail label="Name" value={state.user.name} />
            <Detail label="Email" value={state.user.email} />
            <Detail label="Roles" value={state.user.roles} />
            <Detail label="Context" value={state.user.context_title} />
            <Detail label="Issuer" value={state.user.issuer} />
            <Detail label="Audience" value={state.user.audience} />
          </dl>
        ) : null}
      </section>
    </main>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  const trimmed = value.trim();

  return (
    <div className="grid gap-1 border-b border-gray-100 pb-3 sm:grid-cols-[9rem_1fr] sm:gap-3">
      <dt className="font-medium text-gray-700">{label}</dt>
      <dd className="break-all text-gray-900">
        {trimmed.length > 0 ? trimmed : "None"}
      </dd>
    </div>
  );
}
