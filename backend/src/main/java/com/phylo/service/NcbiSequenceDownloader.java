package com.phylo.service;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * NCBI 序列下载器
 * 
 * 使用 NCBI E-utilities API 获取核酸序列
 * 主要端点：
 * - Entrez Direct (efetch): https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi
 */
@Service
public class NcbiSequenceDownloader {

    private static final String EFETCH_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi";
    private static final String DB_NAME = "nucleotide";
    private static final String RETTYPE = "fasta";
    private static final String RETMODE = "text";
    private static final String EMAIL = "your_email@example.com"; // 请替换为实际邮箱
    
    /**
     * 从 NCBI 获取单个序列的 FASTA 内容
     * 
     * @param accession 序列 Accession Number (如 "NM_001301717")
     * @return FASTA 格式的序列字符串
     * @throws RuntimeException 如果下载失败
     */
    public String downloadSingleSequence(String accession) {
        try {
            URL url = new URL(buildEFetchUrl(accession));
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("GET");
            connection.setConnectTimeout(10000);
            connection.setReadTimeout(15000);
            connection.setRequestProperty("User-Agent", "PhyloPlatform/1.0 (" + EMAIL + ")");
            
            int statusCode = connection.getResponseCode();
            if (statusCode != HttpURLConnection.HTTP_OK) {
                throw new RuntimeException("NCBI 返回错误状态：" + statusCode + 
                    "，可能是 Accession Number 错误或网络问题");
            }
            
            StringBuilder fastaContent = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(connection.getInputStream(), "UTF-8"))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    fastaContent.append(line).append("\n");
                }
            }
            
            connection.disconnect();
            
            if (fastaContent.toString().trim().isEmpty()) {
                throw new RuntimeException("从 NCBI 获取到空序列，请检查 Accession Number 是否正确");
            }
            
            return fastaContent.toString();
            
        } catch (Exception e) {
            throw new RuntimeException("下载 NCBI 序列失败：" + e.getMessage(), e);
        }
    }
    
    /**
     * 从 NCBI 获取多个序列的 FASTA 内容
     * 
     * @param accessions Accession Number 列表
     * @return FASTA 格式的序列字符串（合并多个序列）
     * @throws RuntimeException 如果下载失败
     */
    public String downloadMultipleSequences(List<String> accessions) {
        if (accessions == null || accessions.isEmpty()) {
            throw new IllegalArgumentException("Accession Number 列表不能为空");
        }
        
        if (accessions.size() > 20) {
            throw new IllegalArgumentException("一次最多下载 20 个序列，建议您分批下载");
        }
        
        StringBuilder combinedFasta = new StringBuilder();
        
        for (int i = 0; i < accessions.size(); i++) {
            String accession = accessions.get(i).trim();
            System.out.println("正在下载第 " + (i + 1) + "/" + accessions.size() + " 个序列：" + accession);
            
            try {
                String fasta = downloadSingleSequence(accession);
                combinedFasta.append(fasta).append("\n");
                
                // 避免请求过快被限制，短暂延迟
                if (i < accessions.size() - 1) {
                    Thread.sleep(500);
                }
                
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RuntimeException("下载过程被中断", e);
            }
        }
        
        return combinedFasta.toString();
    }
    
    /**
     * 验证 Accession Number 是否有效
     * 通过尝试下载来验证
     * 
     * @param accession Accession Number
     * @return true 如果有效，false 如果无效
     */
    public boolean validateAccession(String accession) {
        try {
            String fasta = downloadSingleSequence(accession);
            return fasta != null && !fasta.trim().isEmpty();
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * 构建 EFetch API URL
     */
    private String buildEFetchUrl(String accession) {
        return String.format(
            "%s?db=%s&id=%s&rettype=%s&retmode=%s&email=%s",
            EFETCH_URL,
            DB_NAME,
            accession,
            RETTYPE,
            RETMODE,
            EMAIL
        );
    }
    
    /**
     * 批量下载序列（简化版，直接循环调用单一下载）
     */
    public List<String> downloadAsFastas(List<String> accessions) {
        List<String> fastas = new ArrayList<>();
        for (String accession : accessions) {
            try {
                fastas.add(downloadSingleSequence(accession));
            } catch (Exception e) {
                System.err.println("下载失败 " + accession + ": " + e.getMessage());
                // 继续下载下一个
            }
        }
        return fastas;
    }
}
