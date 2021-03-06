#ComBat--------------------------------------------------------------------------------------
library(magrittr)
library(readxl)
library(clusterProfiler)
library(ComplexHeatmap)
library(circlize)
library(sva)
library(org.Hs.eg.db)
library(ggplot2)

#filter melanoma RNA-seq anti-CTLA4
readxl::read_excel("/data/liull/immune-checkpoint-blockade/all_metadata_available.xlsx",col_names = TRUE,sheet="SRA") -> SRA
readxl::read_excel("/data/liull/immune-checkpoint-blockade/all_metadata_available.xlsx",col_names = TRUE,sheet="dbGAP") -> dbGAP
rbind(SRA,dbGAP) %>%
  dplyr::filter(Library_strategy=="RNA-Seq") %>%
  dplyr::filter(Cancer=="melanoma") %>%
  dplyr::filter(Anti_target=="anti-CTLA4") %>%
  dplyr::select(SRA_Study,Run,Response,Biopsy_Time) ->metadata

metadata %>% dplyr::filter(Run != "SRR3083584") -> metadata# fastq file 16M



#expression prepare for batch effect
read.table("/data/liull/immune-checkpoint-blockade/expression/all_count_expression_2.txt",sep="\t",header = T,as.is = TRUE) ->data1
Project=unique(metadata$SRA_Study)
dplyr::filter(metadata,SRA_Study==Project[1]) %>%
  dplyr::select(Run)  %>%
  as.matrix() %>%
  as.character()->Project1_id

dplyr::filter(metadata,SRA_Study==Project[2]) %>%
  dplyr::select(Run)  %>%
  as.matrix() %>%
  as.character()->Project2_id


expression=dplyr::select(data1,gene_id,Project1_id,Project2_id)
#order the expression profile by project to remove batch effect

row.names(expression)=expression[,1]
expression=expression[,-1]
#make rownames to DGEList

DGEList_expr <- DGEList(counts=expression)
normalized_expr <- calcNormFactors(DGEList_expr, method="upperquartile")
normalized_loggedCPM_expr = cpm(normalized_expr, log=TRUE, prior.count=2)

#remove batch effect by ComBat
batch1=rep(1,length(Project1_id))
batch2=rep(2,length(Project2_id))
batch=c(batch1,batch2)
metadata$Response%>%
  gsub("^PD$", "NR",. )%>%
  gsub("^SD$", "NR", .)%>%
  gsub("^PR$", "R", .)%>%
  gsub("^CR$", "R", .)%>%
  gsub("^X$", "R", .)->my_mod
my_mod = model.matrix(~as.factor(my_mod))  #don't consider long term survival
combat_edata = ComBat(dat=normalized_loggedCPM_expr, batch=batch, mod=my_mod, par.prior=TRUE, prior.plots=FALSE)
write.table(combat_edata,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/CTLA4_removed_batch_expression.txt",quote = FALSE,row.names = TRUE,col.names = TRUE)

#DEG by limma
dplyr::filter(metadata,Biopsy_Time=="pre-treatment")%>%
  dplyr::filter(Response %in% c("CR","PR","X","R"))-> response
dplyr::filter(metadata,Biopsy_Time=="pre-treatment")%>%
  dplyr::filter(Response %in% c("SD","PD","NR")) -> non_response

dplyr::select(as.data.frame(combat_edata),response$Run,non_response$Run)->ordered_combat_edata

keep <- rowSums(ordered_combat_edata>0) >= 2
ordered_combat_edata <- ordered_combat_edata[keep,]
#delete the gene has less than 2 sample exression CPM<1(log2CPM<0)

group_list <- factor(c(rep("response",nrow(response)), rep("non_response",nrow(non_response))))
design <- model.matrix(~group_list)
colnames(design) <- levels(group_list)
rownames(design) <- colnames(ordered_combat_edata)

fit <- lmFit(ordered_combat_edata, design)
fit2 <- eBayes(fit)
output <- topTable(fit2, coef=2, n=Inf)
tibble::rownames_to_column(output) %>% dplyr::filter(P.Value<0.05) %>% dplyr::filter(logFC>1)->up
tibble::rownames_to_column(output) %>% dplyr::filter(P.Value<0.05) %>% dplyr::filter(logFC< -1)->down

read.table("/data/liull/reference/EntrezID_Symbl_EnsemblID_NCBI.txt",sep="\t",header = T,as.is = TRUE) ->relationship
merge(relationship,up,by.x="Ensembl_ID",by.y="rowname",all=TRUE)%>%
  dplyr::filter(Ensembl_ID %in% grep("ENSG",up$rowname,value=T)) ->up_ENSG
up_ENSG[order(up_ENSG$logFC,decreasing = TRUE),]->up_ENSG
merge(relationship,down,by.x="Ensembl_ID",by.y="rowname",all=TRUE)%>%
  dplyr::filter(Ensembl_ID %in% grep("ENSG",down$rowname,value=T)) ->down_ENSG
down_ENSG[order(down_ENSG$logFC),]->down_ENSG

write.table(output,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/CTLA4_all_DEG.txt",quote = FALSE,row.names = TRUE,col.names = TRUE)
write.table(up_ENSG,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/CTLA4_up_ENSG.txt",quote = FALSE,row.names = FALSE,col.names = TRUE)
write.table(down_ENSG,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/CTLA4_down_ENSG.txt",quote = FALSE,row.names = FALSE,col.names = TRUE)

#PCA test for combat-----------------------------------------------------------------------------------
#before
pca <- princomp(normalized_loggedCPM_expr)
data.frame(loadings(pca)[,1:3])->pca_before
Projects=c(rep(Project[1],length(Project1_id)),rep(Project[2],length(Project2_id)))
cbind(pca_before,Projects)->pca_before

pdf(file = "/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/PCA_before.pdf", 7.5, 5.5)
ggplot(pca_before,aes(x=pca_before$Comp.1,y=pca_before$Comp.2,color=Projects))+
  geom_point()+
  theme(panel.grid.major=element_blank(),
        panel.grid.minor=element_blank(),
        panel.background = element_blank(),
        axis.line = element_line(colour = "black"),
        panel.border=element_rect(fill = NA))+
  labs(x = "PC1", y = "PC2")
dev.off()
#after
pca_combat <- princomp(combat_edata)
data.frame(loadings(pca_combat)[,1:3])->pc_after
cbind(pc_after,Projects)->pc_after
pdf(file = "/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/PCA_ComBat.pdf", 7.5, 5.5)
ggplot(pc_after,aes(x=pc_after$Comp.1,y=pc_after$Comp.2,color=Projects))+
  geom_point()+
  theme(panel.grid.major=element_blank(),
        panel.grid.minor=element_blank(),
        panel.background = element_blank(),
        axis.line = element_line(colour = "black"),
        panel.border=element_rect(fill = NA))+
  labs(x = "PC1", y = "PC2")
dev.off()

#heatmap for all DEG--------------------------------------------------------
rbind(up_ENSG,down_ENSG)->all_genes
tibble::rownames_to_column(ordered_combat_edata) %>% 
  dplyr::filter(rowname %in% all_genes$Ensembl_ID)->expr_heatmap
rownames(expr_heatmap)=expr_heatmap$rowname
expr_heatmap=expr_heatmap[,-1]

apply(expr_heatmap, 1, scale) ->scaled_expr
rownames(scaled_expr)=colnames(expr_heatmap)
scaled_expr=t(scaled_expr)


df = data.frame(type = c(rep("response", nrow(response)), rep("non_response", nrow(non_response))))
ha = HeatmapAnnotation(df = df,col = list(type = c("response" =  "tomato", "non_response" = "steelblue")))

pdf(file="/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/heatmap_ENSG.pdf")
Heatmap(scaled_expr,name="Color_key",top_annotation = ha,cluster_columns = FALSE,column_names_gp = gpar(fontsize = 2),row_names_gp = gpar(fontsize = 1),col=colorRamp2(c(-4, 0, 4), c("green", "black", "red")))
dev.off()

# > sum(rowSums(scaled_expr>2))
# [1] 208
# > sum(rowSums(scaled_expr< -2))
# [1] 251

# second heatmap
pdf(file="/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/heatmap_ENSG_2.pdf")
Heatmap(scaled_expr,name="Color_key",top_annotation = ha,cluster_columns = FALSE,column_names_gp = gpar(fontsize = 2),row_names_gp = gpar(fontsize = 1),col=colorRamp2(c(-2, 0, 2), c("green", "black", "red")))
dev.off()

#GO enrichment-----------------------------------------------
enrichGO(gene = up_ENSG$GeneID,OrgDb = org.Hs.eg.db,ont = "ALL",pAdjustMethod = "fdr",pvalueCutoff = 0.05,readable = TRUE)->ego_up#14
DOSE::dotplot(ego_up, split="ONTOLOGY") + facet_grid(ONTOLOGY~., scale="free")->ego_up_plot
ggsave(
  filename = 'melanoma_CTLA4_up_GOenrich.pdf',
  plot = ego_up_plot,
  device = 'pdf',
  path = '/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/',
  width = 12,
  height = 8
)

enrichGO(gene = down_ENSG$GeneID,OrgDb = org.Hs.eg.db,ont = "ALL",pAdjustMethod = "fdr",pvalueCutoff = 0.05,readable = TRUE)->ego_down#4
DOSE::dotplot(ego_down, split="ONTOLOGY",showCategory=20) + facet_grid(ONTOLOGY~., scale="free")->ego_down_plot
ggsave(
  filename = 'melanoma_CTLA4_down_GOenrich.pdf',
  plot = ego_down_plot,
  device = 'pdf',
  path = '/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/',
  width = 12,
  height = 8
)

write.table(as.data.frame(ego_up),"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/up_enrichGO.txt",quote = FALSE,sep="\t",row.names = FALSE,col.names = TRUE)#
write.table(as.data.frame(ego_down),"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/down_enrichGO.txt",quote = FALSE,sep="\t",row.names = FALSE,col.names = TRUE)#

#KEGG enrichment----------------------------------------------------------------------------------------
enrichKEGG(gene=up2$GeneID,organism="human",pvalueCutoff=0.05,pAdjustMethod = "BH") ->ekegg_up#0
enrichKEGG(gene=down2$GeneID,organism="human",pvalueCutoff=0.05,pAdjustMethod = "BH")->ekegg_down#0
dotplot(ekegg_up, showCategory=20)->KEGG_up_plot
dotplot(ekegg_down, showCategory=20)->KEGG_down_plot

write.table(as.data.frame(ekegg_up),"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/up_enrichKEGG.txt",quote = FALSE,sep="\t",row.names = FALSE,col.names = TRUE)
write.table(as.data.frame(ekegg_down),"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/down_enrichKEGG.txt",quote = FALSE,sep="\t",row.names = FALSE,col.names = TRUE)


#Reactome enrichment--------------------------------------------------------------------------------------
library(ReactomePA)
enrichPathway(gene=up2$GeneID,organism="human",pvalueCutoff=0.05, readable=T)->eReactome_up
dotplot(eReactome_up, showCategory=20)->Reactome_up_plot#0
enrichPathway(gene=down2$GeneID,organism="human",pvalueCutoff=0.05, readable=T)->eReactome_down
dotplot(eReactome_down, showCategory=20)->Reactome_down_plot#1  Cell surface interactions at the vascular wall

ggsave(
  filename = 'melanoma_CTLA4_down_Reactome.pdf',
  plot = Reactome_down_plot,
  device = 'pdf',
  path = '/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/',
  width = 12,
  height = 8
)

write.table(as.data.frame(eReactome_up),"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/up_enrichReactome.txt",quote = FALSE,sep="\t",row.names = FALSE,col.names = TRUE)
write.table(as.data.frame(eReactome_down),"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_CTLA4/down_enrichReactome.txt",quote = FALSE,sep="\t",row.names = FALSE,col.names = TRUE)


