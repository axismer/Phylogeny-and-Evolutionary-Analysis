package com.phylo.platform.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties({ PhyloDataProperties.class, PhyloRProperties.class })
public class AppConfig {
}
