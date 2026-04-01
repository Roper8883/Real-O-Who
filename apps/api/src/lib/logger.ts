type LogLevel = "debug" | "info" | "warn" | "error";

interface LogPayload {
  message: string;
  [key: string]: unknown;
}

function emit(level: LogLevel, payload: LogPayload) {
  const entry = {
    level,
    timestamp: new Date().toISOString(),
    ...payload,
  };

  const line = JSON.stringify(entry);

  if (level === "error") {
    console.error(line);
    return;
  }

  if (level === "warn") {
    console.warn(line);
    return;
  }

  console.log(line);
}

export const logger = {
  debug(payload: LogPayload) {
    emit("debug", payload);
  },
  info(payload: LogPayload) {
    emit("info", payload);
  },
  warn(payload: LogPayload) {
    emit("warn", payload);
  },
  error(payload: LogPayload) {
    emit("error", payload);
  },
};
