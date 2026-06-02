// 后端服务地址（请替换为实际部署地址）
export const BASE_URL = "http://192.168.137.1:8000"; // 后端 FastAPI 服务地址

// 以图搜图接口
export const SEARCH_IMAGE_URL = `${BASE_URL}/api/v1/search/image`;

// 默认检索参数
export const DEFAULT_TOP_K = 20;
export const DEFAULT_THRESHOLD = 0.4;