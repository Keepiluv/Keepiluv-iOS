import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import path from "node:path";

type RiskLevel = "safe" | "moderate" | "sensitive" | "commit" | "blocked";

type Decision =
  | { level: "safe" }
  | {
      level: "moderate" | "sensitive" | "commit";
      title: string;
      message: string;
      cacheKey?: string;
    }
  | { level: "blocked"; reason: string };

const EXTRA_SENSITIVE_PATHS = [
  "AGENTS.md",
  "CLAUDE.md",
  "docs/Reference/ProjectRules.md",
  "docs/Reference/Checklists.md",
  "docs/Architecture/Overview.md",
  ".pi/skills/",
  ".pi/extensions/",
  "Projects/Domain/Auth/Interface/Sources/TokenManager.swift",
  "Projects/Core/Storage/Interface/Sources/TokenStorageProtocol.swift",
  "Projects/Core/Storage/Sources/KeychainTokenStorage.swift",
  "Projects/Domain/Auth/Sources/AuthInterceptor.swift",
  "fastlane/Fastfile",
  "fastlane/README.md",
  "Tuist/",
  "Tuist.swift",
  "Workspace.swift",
];

export default function (pi: ExtensionAPI) {
  const sessionApproved = new Set<string>();
  let executionApproved = false;

  pi.on("tool_call", async (event, ctx) => {
    let decision: Decision = { level: "safe" };

    if (event.toolName === "read") {
      return undefined;
    }

    if (event.toolName === "bash") {
      decision = classifyBash(getCommand(event.input));
    } else if (event.toolName === "write" || event.toolName === "edit") {
      decision = classifyFileTool(event.toolName, getPath(event.input));
    }

    const result = await enforceDecision(decision, ctx, sessionApproved, executionApproved);
    if (result.executionApproved) executionApproved = true;
    return result.block;
  });
}

function getCommand(input: unknown): string {
  if (typeof input === "object" && input !== null && "command" in input) {
    const command = (input as { command?: unknown }).command;
    return typeof command === "string" ? command.trim() : "";
  }
  return "";
}

function getPath(input: unknown): string {
  if (typeof input === "object" && input !== null && "path" in input) {
    const filePath = (input as { path?: unknown }).path;
    return typeof filePath === "string" ? filePath : "";
  }
  return "";
}

function normalizePath(filePath: string): string {
  const normalized = path.normalize(filePath).replace(/\\/g, "/");
  return normalized.replace(/^\.\//, "");
}

function isSecretPath(filePath: string): boolean {
  const p = normalizePath(filePath).toLowerCase();
  const base = path.posix.basename(p);

  return (
    base === ".env" ||
    base.startsWith(".env.") ||
    /(^|\/)(secrets?|credentials?)(\/|\.|$)/i.test(p) ||
    /(^|\/)(provisioning|signing|certificates?|keychains?)(\/|\.|$)/i.test(p) ||
    /\.(p12|mobileprovision|cer|cert|key|pem)$/i.test(p)
  );
}

function isExtraSensitivePath(filePath: string): boolean {
  const p = normalizePath(filePath);
  return EXTRA_SENSITIVE_PATHS.some((sensitive) => {
    const normalizedSensitive = normalizePath(sensitive);
    return normalizedSensitive.endsWith("/")
      ? p === normalizedSensitive.slice(0, -1) || p.startsWith(normalizedSensitive)
      : p === normalizedSensitive;
  });
}

function sensitiveReason(filePath: string): string {
  const p = normalizePath(filePath);

  if (p === "AGENTS.md" || p === "CLAUDE.md") return "agent baseline / Claude entry point";
  if (p.startsWith("docs/")) return "canonical project documentation";
  if (p.startsWith(".pi/skills/")) return "Pi skill definition";
  if (p.startsWith(".pi/extensions/")) return "Pi extension definition";
  if (p.includes("TokenManager") || p.includes("TokenStorage") || p.includes("KeychainTokenStorage")) {
    return "token storage/auth boundary";
  }
  if (p.includes("AuthInterceptor")) return "authorization header / token refresh infrastructure";
  if (p.startsWith("fastlane/") || p === "fastlane/Fastfile") return "Fastlane verification/deploy configuration";
  if (p.startsWith("Tuist/") || p === "Tuist.swift" || p === "Workspace.swift") return "Tuist project configuration";
  return "extra sensitive project path";
}

function hasShellControl(command: string): boolean {
  return /(;|&&|\|\||\||`|\$\(|\bsh\s+-c\b|\bbash\s+-c\b)/.test(command);
}

function isReadOnlyCommand(command: string): boolean {
  const c = command.trim();
  return (
    /^(pwd)\s*$/.test(c) ||
    /^(ls)(\s+[^;&|`$()]*)?$/.test(c) ||
    /^(find)(\s+[^;&|`$()]*)?$/.test(c) ||
    /^(grep)(\s+[^;&|`$()]*)?$/.test(c) ||
    /^(rg)(\s+[^;&|`$()]*)?$/.test(c) ||
    /^git\s+status(\s+--short)?\s*$/.test(c) ||
    /^git\s+diff\s*$/.test(c) ||
    /^git\s+diff\s+--stat\s*$/.test(c) ||
    /^git\s+diff\s+--cached\s+--stat\s*$/.test(c) ||
    /^git\s+branch\s+--show-current\s*$/.test(c)
  );
}

function classifyBash(command: string): Decision {
  if (!command) return { level: "safe" };
  if (isReadOnlyCommand(command)) return { level: "safe" };

  if (/^git\s+push\b/.test(command)) {
    return { level: "blocked", reason: "twix-gate blocks git push. Push only outside Pi or after extension policy is changed." };
  }
  if (/^git\s+reset\s+--hard\b/.test(command)) {
    return { level: "blocked", reason: "twix-gate blocks git reset --hard. Use a non-destructive review/revert plan instead." };
  }
  if (/^git\s+clean\s+(-[A-Za-z]*f[A-Za-z]*d|-[A-Za-z]*d[A-Za-z]*f)\b/.test(command)) {
    return { level: "blocked", reason: "twix-gate blocks git clean -fd because it deletes untracked files." };
  }
  if (/\brm\s+[^\n]*(-[A-Za-z]*r[A-Za-z]*f|-[A-Za-z]*f[A-Za-z]*r|--recursive)\b/.test(command)) {
    return { level: "blocked", reason: "twix-gate blocks recursive rm. Use targeted deletion after explicit approval." };
  }
  if (/^sudo\b/.test(command) || /\bsudo\b/.test(command)) {
    return { level: "blocked", reason: "twix-gate blocks sudo commands in this repository." };
  }
  if (/^chmod\s+(-R\s+)?(777|[-+][^\s]*w)/.test(command) || /^chown\s+-R\b/.test(command)) {
    return { level: "blocked", reason: "twix-gate blocks broad chmod/chown changes." };
  }
  if (/^xcodebuild\b/.test(command)) {
    return {
      level: "blocked",
      reason: "twix-gate blocks direct xcodebuild unless scheme/destination/configuration were explicitly provided. Use bundle exec fastlane ios ci_pr for normal verification.",
    };
  }

  if (/^git\s+add\s+(\.|-A|--all)\s*$/.test(command)) {
    return sensitive("Sensitive git add confirmation", command, "This stages broad file sets. Session allow is unavailable. Confirm only after reviewing git status and diff.");
  }
  if (/^git\s+add\b/.test(command)) {
    return moderate("Git add confirmation", command, "This stages files for commit. Confirm the file set is intended.", `bash:${command}`);
  }
  if (/^git\s+commit\b/.test(command)) {
    return {
      level: "commit",
      title: "Git commit confirmation",
      message: `Command: ${command}\n\nCommit approval is separate from plan/execution approval. This records repository history. Confirm only if the user approved both file set and commit message.`,
    };
  }
  if (/^(bundle\s+exec\s+)?fastlane\s+ios\s+ci_pr\s*$/.test(command)) {
    return moderate(
      "Run CI/PR verification?",
      command,
      "This runs Fastlane CI/PR verification and may take time.",
      `bash:${command}`,
    );
  }
  if (/^tuist\s+clean\s*$/.test(command)) {
    return moderate("Tuist clean confirmation", command, "This clears Tuist cache/generated state. Continue?", "bash:tuist clean");
  }
  if (/^rm\s+/.test(command)) {
    return moderate("File deletion confirmation", command, "This deletes files. Confirm the target is correct.");
  }

  if (hasShellControl(command)) {
    return moderate("Complex bash command confirmation", command, "This command uses shell control operators. Confirm it is safe to run.");
  }

  return { level: "safe" };
}

function classifyFileTool(toolName: string, filePath: string): Decision {
  const p = normalizePath(filePath);
  if (!p) return { level: "blocked", reason: `twix-gate blocked ${toolName}: missing path.` };

  if (isSecretPath(p)) {
    return { level: "blocked", reason: `twix-gate blocks edits to secrets/env/credentials/provisioning/signing/keychain paths: ${p}` };
  }

  if (isExtraSensitivePath(p)) {
    return {
      level: "sensitive",
      title: "Sensitive file edit confirmation",
      message: `Tool: ${toolName}\nPath: ${p}\nReason: ${sensitiveReason(p)}\n\nSession allow is unavailable for sensitive paths. Confirm only if the user explicitly approved this sensitive edit.`,
    };
  }

  return {
    level: "moderate",
    title: "File edit confirmation",
    message: `Tool: ${toolName}\nPath: ${p}\n\nThis modifies a repository file. Session approval lasts only for this Pi session.`,
    cacheKey: `${toolName}:${p}`,
  };
}

function moderate(title: string, command: string, detail: string, cacheKey?: string): Decision {
  return {
    level: "moderate",
    title,
    message: `Command: ${command}\n\n${detail}\n\nSession approval lasts only for this Pi session.`,
    cacheKey,
  };
}

function sensitive(title: string, command: string, detail: string): Decision {
  return {
    level: "sensitive",
    title,
    message: `Command: ${command}\n\n${detail}`,
  };
}

async function enforceDecision(
  decision: Decision,
  ctx: ExtensionContext,
  sessionApproved: Set<string>,
  executionApproved: boolean,
): Promise<{ block?: { block: true; reason?: string }; executionApproved?: boolean }> {
  if (decision.level === "safe") return {};
  if (decision.level === "blocked") return { block: { block: true, reason: decision.reason } };

  if (!executionApproved) {
    const execution = await askExecutionCheckpoint(decision, ctx);
    if (execution.block) return { block: execution.block };
    executionApproved = execution.executionApproved ?? executionApproved;
  }

  if (decision.level === "moderate" && decision.cacheKey && sessionApproved.has(decision.cacheKey)) {
    return { executionApproved };
  }

  if (!ctx.hasUI) {
    return { block: { block: true, reason: `twix-gate requires confirmation but UI is unavailable: ${decision.title}` } };
  }

  if (decision.level === "moderate") {
    const choice = await selectOrConfirm(
      ctx,
      decision.title,
      `${decision.message}\n\nAllow this action?`,
      ["Allow once", "Allow this action/path/command for this session", "Deny"],
    );

    if (choice === "Deny") {
      return { block: { block: true, reason: `Blocked by twix-gate: ${decision.title}` }, executionApproved };
    }
    if (choice === "Allow this action/path/command for this session" && decision.cacheKey) {
      sessionApproved.add(decision.cacheKey);
    }
    return { executionApproved };
  }

  const title = decision.level === "commit" ? "⚠️ Git commit confirmation" : `⚠️ ${decision.title}`;
  const extra = decision.level === "commit"
    ? "\n\nCommit approval is separate from plan/execution approval. Session allow is unavailable for commits."
    : "\n\nSession allow is unavailable for sensitive actions.";
  const choice = await selectOrConfirm(ctx, title, `${decision.message}${extra}\n\nAllow this action?`, ["Allow once", "Deny"]);

  if (choice !== "Allow once") {
    return { block: { block: true, reason: `Blocked by twix-gate: ${decision.title}` }, executionApproved };
  }

  return { executionApproved };
}

async function askExecutionCheckpoint(
  decision: Exclude<Decision, { level: "safe" } | { level: "blocked" }>,
  ctx: ExtensionContext,
): Promise<{ block?: { block: true; reason?: string }; executionApproved?: boolean }> {
  if (!ctx.hasUI) {
    return { block: { block: true, reason: "twix-gate requires execution approval but UI is unavailable." } };
  }

  const choice = await selectOrConfirm(
    ctx,
    "Start non-read-only execution?",
    [
      "The agent is about to start a non-read-only action.",
      "This checkpoint is separate from plan approval.",
      "It does not override sensitive, commit, or blocked checks.",
      "Action:",
      decision.message,
    ].join("\n\n"),
    ["Allow once", "Start execution for this session", "Deny"],
  );

  if (choice === "Deny") {
    return { block: { block: true, reason: "Blocked by twix-gate: execution checkpoint denied." } };
  }

  return { executionApproved: choice === "Start execution for this session" };
}

async function selectOrConfirm(
  ctx: ExtensionContext,
  title: string,
  message: string,
  choices: string[],
): Promise<string> {
  const ui = ctx.ui as ExtensionContext["ui"] & {
    select?: (prompt: string, options: string[]) => Promise<string | undefined>;
  };

  if (typeof ui.select === "function") {
    const choice = await ui.select(`${title}\n\n${message}`, choices);
    return choice ?? "Deny";
  }

  const ok = await ctx.ui.confirm(title, `${message}\n\n${choices.includes("Allow once") ? "Allow once?" : "Allow?"}`);
  return ok ? "Allow once" : "Deny";
}
