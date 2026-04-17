import { tool } from "@opencode-ai/plugin";

export default tool({
  description: "Switch to or invoke the Ciel primary agent for deep-reasoning workflow",
  args: {
    action: tool.schema.enum(["switch", "invoke"]).describe("Action: switch to Ciel agent or invoke it with a task"),
    task: tool.schema.string().optional().describe("Task description if invoking")
  },
  async execute(args, context) {
    if (args.action === "switch") {
      return "Switching to Ciel agent. Use Tab to cycle agents if needed.";
    }
    
    if (args.action === "invoke" && args.task) {
      return `Invoking Ciel agent with task: ${args.task}\n\nType: @ciel ${args.task}`;
    }
    
    return "Use @ciel to invoke the Ciel agent for deep-reasoning.";
  }
});
