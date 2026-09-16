/**
 * SafeArithmetic — a tokenizer + shunting-yard evaluator for
 * arithmetic expressions. No `eval`, no Function constructor,
 * bounded input length, only numbers and + - * / % ( ) ** and a
 * small set of whitelisted functions.
 */

type Token =
  | { kind: 'num'; value: number }
  | { kind: 'op'; value: string }
  | { kind: 'fn'; value: string }
  | { kind: 'paren'; value: '(' | ')' }
  | { kind: 'comma' };

const FUNCS: Record<string, (...args: number[]) => number> = {
  sqrt: Math.sqrt,
  abs: Math.abs,
  min: Math.min,
  max: Math.max,
  round: Math.round,
  floor: Math.floor,
  ceil: Math.ceil,
  sin: Math.sin,
  cos: Math.cos,
  tan: Math.tan,
  log: Math.log,
  exp: Math.exp,
};

const PRECEDENCE: Record<string, number> = {
  '+': 1,
  '-': 1,
  '*': 2,
  '/': 2,
  '%': 2,
  u: 4, // unary minus
  '^': 3,
};

const MAX_LEN = 500;

export function evaluateExpression(input: string): number {
  const expr = input.replace(/×/g, '*').replace(/÷/g, '/').replace(/,/g, '').trim();
  if (!expr) throw new Error('Empty expression');
  if (expr.length > MAX_LEN) throw new Error('Expression too long');
  if (/[^0-9+\-*/%^().e\s,a-z_]/i.test(expr)) {
    throw new Error('Expression contains unsupported characters');
  }

  const tokens = tokenize(expr);
  const rpn = toRPN(tokens);
  return evalRPN(rpn);
}

function tokenize(expr: string): Token[] {
  const tokens: Token[] = [];
  let i = 0;
  while (i < expr.length) {
    const ch = expr[i];
    if (/\s/.test(ch)) {
      i++;
      continue;
    }
    if (/[0-9.]/.test(ch)) {
      let num = '';
      while (i < expr.length && /[0-9.]/.test(expr[i])) {
        num += expr[i];
        // Allow scientific notation: 1e5
        if (
          (expr[i] === 'e' || expr[i] === 'E') &&
          /[+\-]/.test(expr[i + 1] ?? '')
        ) {
          num += expr[i] + expr[i + 1];
          i += 2;
          continue;
        }
        i++;
      }
      // handle trailing e notation consumed incorrectly
      const value = Number(num.replace(/[^0-9.\-+eE]/g, ''));
      if (!Number.isFinite(value)) throw new Error(`Invalid number: ${num}`);
      tokens.push({ kind: 'num', value });
      continue;
    }
    if (/[a-z_]/i.test(ch)) {
      let name = '';
      while (i < expr.length && /[a-z_0-9]/i.test(expr[i])) {
        name += expr[i];
        i++;
      }
      const lower = name.toLowerCase();
      if (lower === 'pi') {
        tokens.push({ kind: 'num', value: Math.PI });
      } else if (lower === 'e') {
        tokens.push({ kind: 'num', value: Math.E });
      } else if (FUNCS[lower]) {
        tokens.push({ kind: 'fn', value: lower });
      } else {
        throw new Error(`Unknown symbol: ${name}`);
      }
      continue;
    }
    if ('+-*/%^'.includes(ch)) {
      tokens.push({ kind: 'op', value: ch });
      i++;
      continue;
    }
    if (ch === '(' || ch === ')') {
      tokens.push({ kind: 'paren', value: ch });
      i++;
      continue;
    }
    if (ch === ',') {
      tokens.push({ kind: 'comma' });
      i++;
      continue;
    }
    throw new Error(`Unexpected character: ${ch}`);
  }
  return tokens;
}

function toRPN(tokens: Token[]): Token[] {
  const output: Token[] = [];
  const stack: Token[] = [];
  let prev: Token | null = null;

  for (const tok of tokens) {
    if (tok.kind === 'num') {
      output.push(tok);
    } else if (tok.kind === 'fn') {
      stack.push(tok);
    } else if (tok.kind === 'comma') {
      while (stack.length && !(stack[stack.length - 1].kind === 'paren')) {
        output.push(stack.pop()!);
      }
    } else if (tok.kind === 'op') {
      // Unary minus/plus detection.
      let op = tok.value;
      if ((op === '-' || op === '+') && (prev === null || (prev.kind === 'op') || (prev.kind === 'paren' && prev.value === '('))) {
        op = op === '-' ? 'u' : 'up';
      }
      while (stack.length) {
        const top = stack[stack.length - 1];
        if (top.kind === 'op' && PRECEDENCE[top.value] >= PRECEDENCE[op] && op !== '^' && op !== 'u') {
          output.push(stack.pop()!);
        } else if (top.kind === 'op' && PRECEDENCE[top.value] > PRECEDENCE[op]) {
          output.push(stack.pop()!);
        } else {
          break;
        }
      }
      stack.push({ kind: 'op', value: op });
    } else if (tok.kind === 'paren') {
      if (tok.value === '(') {
        stack.push(tok);
      } else {
        while (stack.length && !(stack[stack.length - 1].kind === 'paren')) {
          output.push(stack.pop()!);
        }
        if (!stack.length) throw new Error('Mismatched parentheses');
        stack.pop(); // drop '('
        if (stack.length && stack[stack.length - 1].kind === 'fn') {
          output.push(stack.pop()!);
        }
      }
    }
    prev = tok;
  }
  while (stack.length) {
    const top = stack.pop()!;
    if (top.kind === 'paren') throw new Error('Mismatched parentheses');
    output.push(top);
  }
  return output;
}

function evalRPN(rpn: Token[]): number {
  const stack: number[] = [];
  for (const tok of rpn) {
    if (tok.kind === 'num') {
      stack.push(tok.value);
    } else if (tok.kind === 'fn') {
      const fn = FUNCS[tok.value];
      const argCount = fn.length;
      if (stack.length < argCount) throw new Error(`Not enough arguments for ${tok.value}`);
      const args = stack.splice(stack.length - argCount, argCount);
      const result = fn(...args);
      if (!Number.isFinite(result)) throw new Error('Result is not finite');
      stack.push(result);
    } else if (tok.kind === 'op') {
      if (tok.value === 'u' || tok.value === 'up') {
        const a = stack.pop();
        if (a === undefined) throw new Error('Malformed expression');
        stack.push(tok.value === 'u' ? -a : a);
        continue;
      }
      const b = stack.pop();
      const a = stack.pop();
      if (a === undefined || b === undefined) throw new Error('Malformed expression');
      switch (tok.value) {
        case '+': stack.push(a + b); break;
        case '-': stack.push(a - b); break;
        case '*': stack.push(a * b); break;
        case '/':
          if (b === 0) throw new Error('Division by zero');
          stack.push(a / b);
          break;
        case '%':
          if (b === 0) throw new Error('Division by zero');
          stack.push(a % b);
          break;
        case '^': stack.push(Math.pow(a, b)); break;
        default: throw new Error(`Unknown operator ${tok.value}`);
      }
    }
  }
  if (stack.length !== 1) throw new Error('Malformed expression');
  const result = stack[0];
  if (!Number.isFinite(result)) throw new Error('Result is not finite');
  return result;
}
