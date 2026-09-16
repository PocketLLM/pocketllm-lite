/**
 * Typed repositories for every PocketLLM entity.
 * Singleton instances shared across the app.
 */
import { Repository } from './repository';
import type {
  ActivityEntry,
  AudioTranscript,
  Chat,
  ChatBranch,
  DocumentChunk,
  DocumentRecord,
  DownloadTask,
  ErrorEntry,
  LabRun,
  Memory,
  Message,
  ModelManifest,
  NetworkAuditEntry,
  Note,
  Persona,
  Prompt,
  Provider,
  Skill,
  Tag,
  ToolEvent,
  UsageDay,
} from '@/lib/types/domain';

export const chatRepo = new Repository<Chat>('chats');
export const messageRepo = new Repository<Message>('messages');
export const branchRepo = new Repository<ChatBranch>('branches');
export const personaRepo = new Repository<Persona>('personas');
export const promptRepo = new Repository<Prompt>('prompts');
export const skillRepo = new Repository<Skill>('skills');
export const tagRepo = new Repository<Tag>('tags');
export const noteRepo = new Repository<Note>('notes');
export const memoryRepo = new Repository<Memory>('memories');
export const documentRepo = new Repository<DocumentRecord>('documents');
export const chunkRepo = new Repository<DocumentChunk>('chunks');
export const providerRepo = new Repository<Provider>('providers');
export const modelRepo = new Repository<ModelManifest>('models');
export const downloadRepo = new Repository<DownloadTask>('downloads');
export const toolEventRepo = new Repository<ToolEvent>('toolEvents');
export const networkAuditRepo = new Repository<NetworkAuditEntry>('networkAudit');
export const activityRepo = new Repository<ActivityEntry>('activityLog');
export const errorRepo = new Repository<ErrorEntry>('errorLog');
export const labRunRepo = new Repository<LabRun>('labRuns');
export const transcriptRepo = new Repository<AudioTranscript>('transcripts');
export const usageRepo = new Repository<UsageDay>('usage');
