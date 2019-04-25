#WGCNA for melanoma PD1
library(WGCNA)
library(magrittr)
enableWGCNAThreads(nThreads =20 )
#prepared data traits----------------------------------------------------------------------------
readxl::read_excel("/data/liull/immune-checkpoint-blockade/all_metadata_available.xlsx",col_names = TRUE,sheet="SRA") %>%
  dplyr::filter(Library_strategy=="RNA-Seq") %>%
  dplyr::filter(Cancer=="melanoma") %>%
  dplyr::filter(Anti_target=="anti-PD1") %>%
  dplyr::filter(Biopsy_Time=="pre-treatment")%>%
  dplyr::select(Run,Response)%>%
  as.data.frame()->melanoma_PD1#85 samples
dplyr::filter(melanoma_PD1,Response %in% c("CR","PR","R"))->response#26
dplyr::filter(melanoma_PD1,Response %in% c("PD","SD","NR"))->non_response#59
 


#prepared data expr------------------------------------------------------------------------------
read.table("/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/PD1_removed_batch_expression.txt",header = T,as.is = TRUE) ->all_expression
read.table("/data/liull/reference/EntrezID_Symbl_EnsemblID_NCBI.txt",header = T,as.is = TRUE,sep="\t") -> relationship


tibble::rownames_to_column(all_expression) %>%
  dplyr::select(rowname,melanoma_PD1$Run)%>%
  dplyr::filter(rowname %in% relationship$Ensembl_ID) %>%
  merge(relationship,.,by.x="Ensembl_ID",by.y="rowname")%>%
  dplyr::select(-Ensembl_ID,-GeneID)->melanoma_PD1_expr0  #symbol-PD1-pretreatment-log2CPM-expr
dim(melanoma_PD1_expr0)

factors=factor(melanoma_PD1_expr0$Symbol)
merged_expression=tapply(melanoma_PD1_expr0[,2],factors,median)
for (i in 3:ncol(melanoma_PD1_expr0)) {
  temp=tapply(melanoma_PD1_expr0[,i],factors,median)
  merged_expression=cbind(merged_expression,temp)
}
colnames(merged_expression)=colnames(melanoma_PD1_expr0)[2:ncol(melanoma_PD1_expr0)]  #trans ensembl id to symbol and merged
dim(merged_expression)

keep <- rowSums(merged_expression>0) >= 2
melanoma_PD1_expr1 <- merged_expression[keep,]  #keep the gene has more than 2 CPM>2's sample 
dim(melanoma_PD1_expr1)
write.table(melanoma_PD1_expr1,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/pre_PD1_filtered_symbol_expr.txt",row.names = TRUE,col.names = TRUE,quote=FALSE,sep="\t")
#only the gene has Ensembl id in NCBI_relationship(the one has no ensembl is meaningless,Gene type:pseudo or other)
dplyr::select(as.data.frame(melanoma_PD1_expr1,stringsAsFactors=FALSE),response$Run)->expr_R
  # t()%>%
  # as.data.frame(stringsAsFactors=FALSE)->expr_R
dplyr::select(as.data.frame(melanoma_PD1_expr1,stringsAsFactors=FALSE),non_response$Run)->expr_NR

  # t()%>%
  # as.data.frame(stringsAsFactors=FALSE)->expr_NR#prepare for WGCNA

write.table(expr_R,"/data/liull/test2/expr_R.txt",row.names = TRUE,col.names = TRUE,quote=FALSE,sep="\t")
write.table(expr_NR,"/data/liull/test2/expr_NR.txt",row.names = TRUE,col.names = TRUE,quote=FALSE,sep="\t")


#WGCNA3.r expr_R.txt 0.85 30 0.25
#WGCNA3.r expr_NR.txt 0.85 30 0.25
#with the sets WGCNA get,do Univariate Cox regression----------------------------------------------------------------------------------
library(magrittr)
read.table("/data/liull/test_WGCNA_R/module.color.txt",header = F,as.is = TRUE,skip = 1) ->R_color_module #response modules
cbind(R_color_module[1:2,],R_color_module[3:4,])%>%
  cbind(R_color_module[5:6,])%>%
  cbind(R_color_module[7:8,])%>%
  cbind(R_color_module[9:10,])%>%
  cbind(R_color_module[11:12,])%>%
  cbind(R_color_module[13:14,])%>%
  cbind(R_color_module[15:16,])%>%
  t()%>%
  as.data.frame(stringsAsFactors=FALSE)->R_color_module
colnames(R_color_module)=c("module","Num")
rownames(R_color_module)=NULL
dplyr::filter(R_color_module,module != "grey")->R_color_module

read.table("/data/liull/test_WGCNA_R/raw_module.assign.txt",header = T,as.is = TRUE) %>%
  dplyr::filter(module != "grey")->R_color_gene

R_list_sets=list()
R_module_names=character()
for (i in 1:nrow(R_color_module)) {
  
  R_color_module$module[i] -> R_module_names[i]
  dplyr::filter(R_color_gene,module == R_module_names[i])%>%
    dplyr::select(gene)%>%
    as.matrix()%>%
    as.character()%>%
    list()->R_list_sets[i]
  
}
names(R_list_sets)=paste("R_",R_module_names,sep="")


read.table("/data/liull/test_WGCNA_NR/module.color.txt",header = F,as.is = TRUE,skip = 1,fill = T) ->NR_color_module #non_response modules
cbind(NR_color_module[1:2,],NR_color_module[3:4,])%>%
  cbind(NR_color_module[5:6,])%>%
  cbind(NR_color_module[7:8,])%>%
  cbind(NR_color_module[9:10,])%>%
  cbind(NR_color_module[11:12,])%>%
  cbind(NR_color_module[13:14,])%>%
  cbind(NR_color_module[15:16,])%>%
  cbind(NR_color_module[17:18,])%>%
  cbind(NR_color_module[19:20,])%>%
  t()%>%
  as.data.frame(stringsAsFactors=FALSE)->NR_color_module
colnames(NR_color_module)=c("module","Num")
rownames(NR_color_module)=NULL
dplyr::filter(NR_color_module,module != "grey") %>%
  dplyr::filter(module != "")->NR_color_module

read.table("/data/liull/test_WGCNA_NR/raw_module.assign.txt",header = T,as.is = TRUE) %>%
  dplyr::filter(module != "grey") ->NR_color_gene

NR_list_sets=list()
NR_module_names=character()
for (i in 1:nrow(NR_color_module)) {
  
  NR_color_module$module[i] -> NR_module_names[i]
  dplyr::filter(NR_color_gene,module == NR_module_names[i])%>%
    dplyr::select(gene)%>%
    as.matrix()%>%
    as.character()%>%
    list()->NR_list_sets[i]
  
}
names(NR_list_sets)=paste("NR_",NR_module_names,sep="")


list_sets=c(R_list_sets,NR_list_sets)

read.table("/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/pre_PD1_filtered_symbol_expr.txt",header = T,as.is = TRUE)->pre_PD1_expr

readxl::read_excel("/data/liull/immune-checkpoint-blockade/all_metadata_available.xlsx",col_names = TRUE,sheet="SRA") %>%
  dplyr::filter(Library_strategy=="RNA-Seq") %>%
  dplyr::filter(Cancer=="melanoma") %>%
  dplyr::filter(Anti_target=="anti-PD1") %>%
  dplyr::filter(Survival_time != "NA")%>%
  dplyr::filter(Biopsy_Time=="pre-treatment")%>%###
  dplyr::select(Run,Response,Survival_time,Survival_status,Age,Gender) ->metadata


ssgava_score <- gsva(as.matrix(pre_PD1_expr), list_sets, min.sz=1, max.sz=999999, method="ssgsea",kcdf="Gaussian")

t(ssgava_score) %>%
  as.data.frame(stringsAsFactors=FALSE)->t_ssgava_score
cbind(rownames(t_ssgava_score),t_ssgava_score)->t_ssgava_score
rownames(t_ssgava_score)=NULL
colnames(t_ssgava_score)[1]="Run"

Combined_data=merge(metadata[,c(1,3,4,5,6)],t_ssgava_score)

for (j in 1:nrow(Combined_data)) {
  if(Combined_data$Survival_status[j]=="Dead"){
    Combined_data$Survival_status[j]="2"
  }else {
    Combined_data$Survival_status[j]="1"
  }
}

for (j in 1:nrow(Combined_data)) {
  if(Combined_data$Gender[j]=="female"){
    Combined_data$Gender[j]="2"
  }else if(Combined_data$Gender[j]=="male") {
    Combined_data$Gender[j]="1"
  }
}

Combined_data$Survival_time=as.numeric(Combined_data$Survival_time)
Combined_data$Survival_status=as.numeric(Combined_data$Survival_status)
Combined_data$Age=as.numeric(Combined_data$Age)
Combined_data$Gender=as.numeric(Combined_data$Gender)

#Univariate Cox regression
covariates <- colnames(Combined_data)[-c(1,2,3)]

univ_formulas <- sapply(covariates,
                        function(x) as.formula(paste('Surv(Survival_time, Survival_status)~',x)))

univ_models <- lapply(univ_formulas, function(x){coxph(x, data = Combined_data)})
# Extract data 
univ_results <- lapply(univ_models,
                       function(x){ 
                         x <- summary(x)
                         p.value<-signif(x$wald["pvalue"], digits=2)
                         wald.test<-signif(x$wald["test"], digits=2)
                         beta<-signif(x$coef[1], digits=2);#coeficient beta
                         HR <-signif(x$coef[2], digits=2);#exp(beta)
                         HR.confint.lower <- signif(x$conf.int[,"lower .95"], 2)
                         HR.confint.upper <- signif(x$conf.int[,"upper .95"],2)
                         HR <- paste0(HR, " (", 
                                      HR.confint.lower, "-", HR.confint.upper, ")")
                         res<-c(beta, HR, wald.test, p.value)
                         names(res)<-c("beta", "HR (95% CI for HR)", "wald.test", 
                                       "p.value")
                         return(res)
                         #return(exp(cbind(coef(x),confint(x))))
                       })


res <- as.data.frame(t(as.data.frame(univ_results, check.names = FALSE)),stringsAsFactors=FALSE)
res$p.value=as.numeric(res$p.value)


cbind(rownames(res),res)->filter_res
colnames(filter_res)[1]="module"
filter_res %>%
  dplyr::filter(p.value<=0.05)%>%
  dplyr::select(module)->selected_modules
# > selected_modules
# module
# 1          R_orange
# 2           R_plum1
# 3        R_skyblue3  **
# 4  NR_mediumpurple3
# 5   NR_midnightblue  **
# 6     NR_orangered4  *
# 7         NR_purple
# 8       NR_skyblue3
# 9           NR_tan
# 10         NR_white  **
Combined_data %>%
  dplyr::select(Run,Survival_time,Survival_status,as.character(selected_modules[3,1]))%>%
  dplyr::mutate(Class=rep("class",nrow(Combined_data)))-> Combined_module_1
cutoff=mean(Combined_module_1[,4])

for (i in 1:nrow(Combined_module_1)) {
  if(Combined_module_1[i,4]>=cutoff){
    Combined_module_1$Class[i]="high"
  }else {
    Combined_module_1$Class[i]="low"
  }
}

fit <- survfit(Surv(Survival_time, Survival_status) ~ Class, data = Combined_module_1)

pdf(file="/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/R_skyblue3_survival.pdf")
ggsurvplot(fit, data = Combined_module_1, pval = TRUE,risk.table = TRUE,risk.table.col = "strata")
dev.off()

pdf(file="/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/NR_midnightblue_survival.pdf")
ggsurvplot(fit, data = Combined_module_1, pval = TRUE,risk.table = TRUE,risk.table.col = "strata")
dev.off()

pdf(file="/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/NR_orangered4_survival.pdf")
ggsurvplot(fit, data = Combined_module_1, pval = TRUE,risk.table = TRUE,risk.table.col = "strata")
dev.off()

pdf(file="/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/NR_white_survival.pdf")
ggsurvplot(fit, data = Combined_module_1, pval = TRUE,risk.table = TRUE,risk.table.col = "strata")
dev.off()

write.table(list_sets$R_skyblue3,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/R_skyblue3.txt",row.names = FALSE,col.names = FALSE,quote=FALSE,sep="\t")
write.table(list_sets$NR_midnightblue,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/NR_midnightblue.txt",row.names = FALSE,col.names = FALSE,quote=FALSE,sep="\t")
write.table(list_sets$NR_orangered4,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/NR_orangered4.txt",row.names = FALSE,col.names = FALSE,quote=FALSE,sep="\t")
write.table(list_sets$NR_white,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/NR_white.txt",row.names = FALSE,col.names = FALSE,quote=FALSE,sep="\t")

# write.table(list_sets$R_orange,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/R_orange.txt",row.names = FALSE,col.names = FALSE,quote=FALSE,sep="\t")
# write.table(list_sets$R_plum1,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/R_plum1.txt",row.names = FALSE,col.names = FALSE,quote=FALSE,sep="\t")
# write.table(list_sets$NR_mediumpurple3,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/NR_mediumpurple3.txt",row.names = FALSE,col.names = FALSE,quote=FALSE,sep="\t")
# write.table(list_sets$NR_purple,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/NR_purple.txt",row.names = FALSE,col.names = FALSE,quote=FALSE,sep="\t")
# write.table(list_sets$NR_skyblue3,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/NR_skyblue3.txt",row.names = FALSE,col.names = FALSE,quote=FALSE,sep="\t")
# write.table(list_sets$NR_tan,"/data/liull/immune-checkpoint-blockade/New_batch_effect_pipeline/melanoma_PD1/survival/modules/WGCNA/NR_tan.txt",row.names = FALSE,col.names = FALSE,quote=FALSE,sep="\t")


#gene sets heatmap
dplyr::filter(metadata,Response %in% c("CR","PR")) -> response#
dplyr::filter(metadata,Response %in% c("SD","PD")) -> non_response#

dplyr::filter(color_gene,module=="skyblue3") %>% dplyr::select(gene) %>% as.matrix() %>%as.character()->skyblue3_genes
tibble::rownames_to_column(pre_PD1_expr) %>%
  dplyr::filter(rowname %in% skyblue3_genes) %>%
  dplyr::select(rowname,response$Run,non_response$Run)->skyblue3_expr
rownames(skyblue3_expr)=skyblue3_expr$rowname
skyblue3_expr[,-1]->skyblue3_expr

apply(skyblue3_expr, 1, scale) ->scaled_expr
rownames(scaled_expr)=colnames(skyblue3_expr)
scaled_expr=t(scaled_expr)


df = data.frame(type = c(rep("response", nrow(response)), rep("non_response", nrow(non_response))))
ha = HeatmapAnnotation(df = df,col = list(type = c("response" =  "tomato", "non_response" = "steelblue")))
Heatmap(scaled_expr,name="Color_key",top_annotation = ha,cluster_columns = FALSE,column_names_gp = gpar(fontsize = 2),row_names_gp = gpar(fontsize = 6),col=colorRamp2(c(-3, 0, 3), c("green", "black", "red")))