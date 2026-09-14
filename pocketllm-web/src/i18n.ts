import { useLiveValue } from "./core/live";
import { db } from "./db/db";

export type Locale = "en" | "es" | "zh" | "ja" | "ko" | "hi";

const en = {
  chat: "Chat", history: "History", knowledge: "Knowledge", models: "Models",
  library: "Library", personas: "Personas", prompts: "Prompts", skills: "Skills",
  memories: "Memories", notes: "Notes", audio: "Audio", lab: "Lab",
  promptLab: "Prompt Lab", compare: "Compare", benchmark: "Benchmark",
  starred: "Starred", tags: "Tags", archived: "Archived", providers: "Providers",
  statistics: "Statistics", settings: "Settings", newChat: "New chat"
};
type Key = keyof typeof en;
const catalogs: Record<Locale, Partial<Record<Key,string>>> = {
  en,
  es: { chat:"Chat",history:"Historial",knowledge:"Conocimiento",models:"Modelos",library:"Biblioteca",personas:"Personas",prompts:"Prompts",skills:"Habilidades",memories:"Memorias",notes:"Notas",audio:"Audio",lab:"Laboratorio",promptLab:"Laboratorio de prompts",compare:"Comparar",benchmark:"Rendimiento",starred:"Destacados",tags:"Etiquetas",archived:"Archivados",providers:"Proveedores",statistics:"Estadísticas",settings:"Ajustes",newChat:"Nuevo chat" },
  zh: { chat:"聊天",history:"历史",knowledge:"知识库",models:"模型",library:"资料库",personas:"角色",prompts:"提示词",skills:"技能",memories:"记忆",notes:"笔记",audio:"音频",lab:"实验室",promptLab:"提示词实验室",compare:"对比",benchmark:"基准测试",starred:"收藏",tags:"标签",archived:"归档",providers:"提供商",statistics:"统计",settings:"设置",newChat:"新聊天" },
  ja: { chat:"チャット",history:"履歴",knowledge:"ナレッジ",models:"モデル",library:"ライブラリ",personas:"ペルソナ",prompts:"プロンプト",skills:"スキル",memories:"メモリ",notes:"ノート",audio:"音声",lab:"ラボ",promptLab:"プロンプトラボ",compare:"比較",benchmark:"ベンチマーク",starred:"スター",tags:"タグ",archived:"アーカイブ",providers:"プロバイダー",statistics:"統計",settings:"設定",newChat:"新しいチャット" },
  ko: { chat:"채팅",history:"기록",knowledge:"지식",models:"모델",library:"라이브러리",personas:"페르소나",prompts:"프롬프트",skills:"스킬",memories:"메모리",notes:"노트",audio:"오디오",lab:"랩",promptLab:"프롬프트 랩",compare:"비교",benchmark:"벤치마크",starred:"별표",tags:"태그",archived:"보관됨",providers:"제공자",statistics:"통계",settings:"설정",newChat:"새 채팅" },
  hi: { chat:"चैट",history:"इतिहास",knowledge:"ज्ञान",models:"मॉडल",library:"लाइब्रेरी",personas:"पर्सोना",prompts:"प्रॉम्प्ट",skills:"स्किल्स",memories:"मेमोरी",notes:"नोट्स",audio:"ऑडियो",lab:"लैब",promptLab:"प्रॉम्प्ट लैब",compare:"तुलना",benchmark:"बेंचमार्क",starred:"स्टारred",tags:"टैग",archived:"आर्काइव",providers:"प्रोवाइडर",statistics:"आँकड़े",settings:"सेटिंग्स",newChat:"नई चैट" }
};

export function translate(locale: Locale, key: Key) {
  return catalogs[locale]?.[key] ?? en[key];
}

export function useI18n() {
  const row = useLiveValue(() => db.settings.get("language"), undefined, []);
  const locale = (String(row?.value ?? "en") as Locale);
  return { locale, t: (key: Key) => translate(locale, key) };
}
