package com.phylo.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.*;

/**
 * AI 分析服务 - 集成 DeepSeek 大语言模型
 * 
 * 使用 DeepSeek Chat Completions API 进行生物学专业分析
 */
@Service
public class AiAnalysisService {

    @Value("${ai.deepseek.api.key:}")
    private String deepSeekApiKey;

    @Value("${ai.deepseek.base.url:https://api.deepseek.com/v1}")
    private String deepSeekBaseUrl;

    private static final String DEEPSEEK_MODEL = "deepseek-chat";

    /**
     * 解读系统发育树
     */
    public String interpretPhylogeneticTree(String newickTree, List<String> sequenceNames, String buildMethod) {
        if (newickTree == null || newickTree.isBlank()) {
            throw new IllegalArgumentException("Newick 树不能为空");
        }

        String prompt = buildTreeInterpretationPrompt(newickTree, sequenceNames, buildMethod);
        
        try {
            return callDeepSeek(prompt, "科学分析报告风格");
        } catch (Exception e) {
            // 降级处理：返回基础解读
            return generateFallbackTreeInterpretation(sequenceNames, buildMethod);
        }
    }

    /**
     * 分析距离矩阵
     */
    public String analyzeDistanceMatrix(List<List<Double>> matrix, List<String> names) {
        if (matrix == null || matrix.isEmpty()) {
            throw new IllegalArgumentException("距离矩阵不能为空");
        }

        String prompt = buildMatrixAnalysisPrompt(matrix, names);
        
        try {
            return callDeepSeek(prompt, "数据分析报告风格");
        } catch (Exception e) {
            // 降级处理
            return generateFallbackMatrixAnalysis(matrix, names);
        }
    }

    /**
     * 生成生物学分析报告
     */
    public String generateBiologicalReport(Map<String, Object> data) {
        String prompt = buildBiologicalReportPrompt(data);
        
        try {
            return callDeepSeek(prompt, "科研论文风格");
        } catch (Exception e) {
            // 降级处理
            return generateFallbackReport(data);
        }
    }

    /**
     * 检查 DeepSeek 服务是否可用
     */
    public boolean isDeepSeekAvailable() {
        if (deepSeekApiKey == null || deepSeekApiKey.isBlank()) {
            System.out.println("⚠️ DeepSeek API Key 未配置");
            return false;
        }
        
        try {
            RestTemplate restTemplate = new RestTemplate();
            HttpHeaders headers = new HttpHeaders();
            headers.set(HttpHeaders.AUTHORIZATION, "Bearer " + deepSeekApiKey);
            headers.setContentType(MediaType.APPLICATION_JSON);
            
            Map<String, Object> payload = new HashMap<>();
            payload.put("model", DEEPSEEK_MODEL);
            payload.put("messages", Collections.singletonList(
                Map.of("role", "user", "content", "Hello")
            ));
            payload.put("stream", false);
            
            HttpEntity<Map<String, Object>> request = new HttpEntity<>(payload, headers);
            restTemplate.postForObject(deepSeekBaseUrl + "/chat/completions", request, Object.class);
            
            System.out.println("✅ DeepSeek 服务连接成功");
            return true;
            
        } catch (Exception e) {
            System.err.println("❌ DeepSeek 服务不可用：" + e.getMessage());
            return false;
        }
    }

    /**
     * 调用 DeepSeek API
     */
    private String callDeepSeek(String userMessage, String responseStyle) throws Exception {
        if (deepSeekApiKey == null || deepSeekApiKey.isBlank()) {
            throw new RuntimeException("DeepSeek API Key 未配置，请在 application.properties 中设置 ai.deepseek.api.key");
        }

        RestTemplate restTemplate = new RestTemplate();
        HttpHeaders headers = new HttpHeaders();
        headers.set(HttpHeaders.AUTHORIZATION, "Bearer " + deepSeekApiKey);
        headers.setContentType(MediaType.APPLICATION_JSON);

        // 构建消息历史（保持上下文对话能力）
        List<Map<String, String>> messages = new ArrayList<>();
        messages.add(Map.of(
            "role", "system",
            "content", "你是一位专业的生物信息学专家，擅长解读系统发育树和序列数据。请用中文回答，内容要准确、专业、易理解。"
        ));
        
        messages.add(Map.of(
            "role", "user",
            "content", userMessage + "\n\n请按照" + responseStyle + "给出详细分析报告。"
        ));

        Map<String, Object> payload = new HashMap<>();
        payload.put("model", DEEPSEEK_MODEL);
        payload.put("messages", messages);
        payload.put("temperature", 0.7);
        payload.put("max_tokens", 4000);
        payload.put("stream", false);

        HttpEntity<Map<String, Object>> request = new HttpEntity<>(payload, headers);
        
        Map<String, Object> response = restTemplate.postForObject(
            deepSeekBaseUrl + "/chat/completions",
            request,
            Map.class
        );

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> choices = (List<Map<String, Object>>) response.get("choices");
        if (choices == null || choices.isEmpty()) {
            throw new RuntimeException("API 返回空结果");
        }

        @SuppressWarnings("unchecked")
        Map<String, Object> message = (Map<String, Object>) choices.get(0).get("message");
        return (String) message.get("content");
    }

    // ==================== Prompt 构建方法 ====================

    private String buildTreeInterpretationPrompt(String newickTree, List<String> seqNames, String method) {
        return String.format("""
            我构建了一个系统发育树，以下是详细信息：
            
            【建树方法】
            ：%s
            
            【序列名称列表】
            %s
            
            【Newick 格式进化树】
            %s
            
            请以专业的角度帮我解读这份系统发育树，包括：
            1. 哪些物种/序列在进化上关系最近？为什么？
            2. 主要的进化分支结构是什么？
            3. 树的拓扑结构暗示了什么生物学意义？
            4. 有哪些值得注意的进化关系或异常模式？
            
            请用通俗易懂但又不失专业性的语言解释，适合给研究生看。
            """,
            method,
            String.join(", ", seqNames),
            newickTree
        );
    }

    private String buildMatrixAnalysisPrompt(List<List<Double>> matrix, List<String> names) {
        // 构建矩阵的文本表示
        StringBuilder matrixText = new StringBuilder();
        for (int i = 0; i < matrix.size(); i++) {
            matrixText.append(names.get(i) + ": ");
            matrixText.append(String.join(", ", 
                matrix.get(i).stream().map(Object::toString).toArray(String[]::new)
            ));
            matrixText.append("\n");
        }

        return String.format("""
            我有一个 p-distance 距离矩阵，请帮我分析序列间的亲缘关系：
            
            【序列名称】
            %s
            
            【距离矩阵】
            %s
            
            请分析：
            1. 哪两个序列之间的遗传距离最小？这意味着什么？
            2. 最大距离出现在哪对序列间？说明了什么？
            3. 是否存在某些序列形成明显的聚类？
            4. 这些距离值在分子进化上的含义是什么？
            """,
            String.join(", ", names),
            matrixText.toString()
        );
    }

    private String buildBiologicalReportPrompt(Map<String, Object> data) {
        StringBuilder reportBuilder = new StringBuilder();
        reportBuilder.append("基于以下实验数据，生成一份专业的生物学分析报告：\n\n");
        
        for (Map.Entry<String, Object> entry : data.entrySet()) {
            reportBuilder.append(entry.getKey()).append(": ").append(entry.getValue()).append("\n");
        }
        
        reportBuilder.append("\n请包含以下内容：\n");
        reportBuilder.append("1. 实验背景和研究目的\n");
        reportBuilder.append("2. 主要发现和统计特征\n");
        reportBuilder.append("3. 生物学意义的深度解读\n");
        reportBuilder.append("4. 可能的应用价值和研究建议\n");
        reportBuilder.append("5. 参考文献风格的专业表述\n");
        
        return reportBuilder.toString();
    }

    // ==================== 降级处理（Fallback）=====================

    private String generateFallbackTreeInterpretation(List<String> seqNames, String method) {
        return String.format(
            "【系统发育树基础解读】（AI 服务不可用时自动降级）\n\n" +
            "分析方法：%s\n\n" +
            "参与分析的序列共有 %d 条：%s\n\n" +
            "由于 AI 分析服务暂时不可用，建议您：\n" +
            "1. 查看距离矩阵确定序列间的遗传距离\n" +
            "2. 观察树的拓扑结构识别近缘关系\n" +
            "3. 检查分支长度判断分化程度\n\n" +
            "提示：您可以在 application.properties 中配置 DeepSeek API Key 启用智能分析功能。\n",
            method,
            seqNames.size(),
            String.join(", ", seqNames)
        );
    }

    private String generateFallbackMatrixAnalysis(List<List<Double>> matrix, List<String> names) {
        return String.format(
            "【距离矩阵基础统计】（AI 服务不可用时自动降级）\n\n" +
            "矩阵大小：%dx%d\n\n" +
            "请手动分析以下数据：\n",
            matrix.size(),
            matrix.size()
        );
    }

    private String generateFallbackReport(Map<String, Object> data) {
        return "【报告生成失败】（AI 服务不可用时自动降级）\n\n" +
               "当前无法生成 AI 辅助报告。\n\n" +
               "可用数据:\n" +
               data.keySet().stream()
                   .map(k -> k + ": " + data.get(k))
                   .toArray(String[]::new);
    }
}
