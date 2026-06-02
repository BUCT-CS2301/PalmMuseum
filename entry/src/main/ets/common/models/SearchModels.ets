export interface SearchResultItem {
  objectId: string;
  title: string;
  period: string;
  type: string;
  material: string;
  imageUrl: string;
  similarity: number;
}

interface GeneratedTypeLiteralInterface_1 {
  results: SearchResultItem[];
}

export interface SearchResponse {
  code: number;
  message: string;
  data: GeneratedTypeLiteralInterface_1;
}