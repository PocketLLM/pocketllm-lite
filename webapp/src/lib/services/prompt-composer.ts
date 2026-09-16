/**
 * PromptComposer — assembles the final system prompt in the exact
 * layered order used by the mobile app:
 *
 *   base policy → persona → skills → memory → documents → tools
 */
import type { Memory, Persona, Skill } from '@/lib/types/domain';

export interface ComposerContext {
  persona?: Persona | null;
  skills?: Skill[];
  memories?: Memory[];
  documentContext?: { name: string; excerpt: string }[];
}

const BASE_POLICY = `You are PocketLLM, a private local-first AI assistant. You are helpful, direct and concise by default. Format answers in Markdown. Use fenced code blocks with language tags for code. When you do not know something or a capability is unknown, say so plainly — never invent capabilities or results.`;

export class PromptComposer {
  /** Composes the layered system prompt. */
  compose(ctx: ComposerContext): string {
    const layers: string[] = [BASE_POLICY];

    if (ctx.persona) {
      layers.push(
        `## Persona\nYou are currently acting as "${ctx.persona.name}". Follow these custom instructions:\n${ctx.persona.instructions}`
      );
    }

    if (ctx.skills?.length) {
      const skillText = ctx.skills
        .map((s) => `### Skill: ${s.name}\n${s.instructions}`)
        .join('\n\n');
      layers.push(`## Active skills\n${skillText}`);
    }

    if (ctx.memories?.length) {
      const memoryText = ctx.memories
        .map((m) => `- (${m.type}) ${m.fact}`)
        .join('\n');
      layers.push(
        `## Memory\nThings you remember about this user (use naturally, do not recite):\n${memoryText}`
      );
    }

    if (ctx.documentContext?.length) {
      const docText = ctx.documentContext
        .map((d, i) => `[${i + 1}] ${d.name}:\n${d.excerpt}`)
        .join('\n\n');
      layers.push(
        `## Retrieved documents\nAnswer using these excerpts when relevant. Cite them inline as [1], [2]…\n${docText}`
      );
    }

    return layers.join('\n\n');
  }

  /**
   * Debug breakdown of the composition — shown in Prompt Lab.
   */
  describeLayers(ctx: ComposerContext): Array<{ layer: string; present: boolean; chars: number }> {
    const persona = ctx.persona
      ? `Persona: ${ctx.persona.name} — ${ctx.persona.instructions}`
      : '';
    const skills = (ctx.skills ?? [])
      .map((s) => `Skill ${s.name}: ${s.instructions}`)
      .join('\n');
    const memories = (ctx.memories ?? []).map((m) => m.fact).join('\n');
    const docs = (ctx.documentContext ?? []).map((d) => `${d.name}: ${d.excerpt}`).join('\n');
    return [
      { layer: 'Base policy', present: true, chars: BASE_POLICY.length },
      { layer: 'Persona', present: !!persona, chars: persona.length },
      { layer: 'Skills', present: !!skills, chars: skills.length },
      { layer: 'Memory', present: !!memories, chars: memories.length },
      { layer: 'Documents', present: !!docs, chars: docs.length },
    ];
  }
}

export const promptComposer = new PromptComposer();
