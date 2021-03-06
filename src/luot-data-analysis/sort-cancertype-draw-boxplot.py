# -*- coding: utf-8 -
'''
包含以下函数：
    get_TILs_Info()  用于获得tils文件中的信息。默认文件路径'../raw_data/TIL_result'。返回为dataframe
    get_sorted_patients() 获得病人的信息，并根据不同的cancer type，response type分类。在处理数据时，过滤掉没有药物信息的样本
                        Response定义为 Complete Response，Partial Response，stable disease
                        Nonresponse定义为 progressive disease
                        返回的四个dataframe （metastatic_melanoma_R 组,get_metastatic_melanoma_NR组,metastatic_gastric_cancer_R组,
                        get_metastatic_gastric_cancer_NR组）
    join_TILs_Patients_Info() 连接病人样本文件信息和tils。条件是病人样本文件信息Run列等于tils sample 列
'''
import os
import pandas as pd 
import scipy.stats as stats
import xlrd
import matplotlib.pyplot as plt 
import seaborn as sns
import numpy as np

c_t=['CD4_naive', 'CD8_naive', 'Cytotoxic', 'Exhausted', 'Tr1',
       'nTreg', 'iTreg', 'Th1', 'Th2', 'Th17', 'Tfh', 'Central_memory',
       'Effector_memory', 'NKT', 'MAIT', 'DC', 'Bcell', 'Monocyte',
       'Macrophage', 'NK', 'Neutrophil', 'Gamma_delta', 'CD4_T', 'CD8_T']


def get_TILs_Info():#用于获取TILs的信息
    TILs_Info =pd.read_table('../raw_data/TIL_result')
    return TILs_Info

def get_sorted_patients():
    excel=pd.ExcelFile('../raw_data/metadata-verified.xlsx')
    patient_Info=pd.read_excel(excel)
    patient_Info=patient_Info.iloc[:,0:24]#由于最后一行为一些统计的数据所以用切片的方式切掉 
    
    TILs_Info=get_TILs_Info()
    total_sample_name=TILs_Info.iloc[:,0]
    Filter=pd.DataFrame()
    for sample_id in total_sample_name:
        Filter=Filter.append(patient_Info.loc[patient_Info['Run'] == sample_id])#根据Run的列中的ID与TILs中的sample ID匹配出相应的样本信息
    
    Filter.to_excel("../data/First_join_metadata_Tils.xlsx")

    Filter=Filter[Filter['anti-target']=='anti-PD-1']#筛选出anti-target 为anti-PD-1 的个体由于某些缺乏drug信息，所以以anti-target为准。
    Filter.to_excel("../data/tmp.xlsx")
    Filter = dict(list(Filter.groupby(['Cancer type','response'])))

    get_metastatic_melanoma_R=Filter['metastatic melanoma','R']
    get_metastatic_melanoma_NR=Filter['metastatic melanoma','NR']
    get_metastatic_melanoma_CR=Filter['metastatic melanoma','Complete Response']
    get_metastatic_melanoma_PR=Filter['metastatic melanoma','Partial Response']
    get_metastatic_melanoma_PD=Filter['metastatic melanoma','Progressive Disease']
    get_metastatic_gastric_cancer_CR=Filter['metastatic gastric cancer ','complete response']
    get_metastatic_gastric_cancer_PR=Filter['metastatic gastric cancer ','partial response']
    get_metastatic_gastric_cancer_PD=Filter['metastatic gastric cancer ','progressive disease']
    get_metastatic_gastric_cancer_SD=Filter['metastatic gastric cancer ','stable disease']

    metastatic_melanoma_R=pd.concat([get_metastatic_melanoma_CR,get_metastatic_melanoma_PR,get_metastatic_melanoma_R])
    metastatic_melanoma_NR=pd.concat([get_metastatic_melanoma_PD,get_metastatic_melanoma_NR])
    metastatic_gastric_cancer_R=pd.concat([get_metastatic_gastric_cancer_CR,get_metastatic_gastric_cancer_PR])
    metastatic_gastric_cancer_NR=pd.concat([get_metastatic_gastric_cancer_PD,get_metastatic_gastric_cancer_SD])
    

    return(metastatic_melanoma_R,metastatic_melanoma_NR,metastatic_gastric_cancer_R,metastatic_gastric_cancer_NR)  


def join_TILs_Patients_Info():
    (metastatic_melanoma_R,metastatic_melanoma_NR,metastatic_gastric_cancer_R,metastatic_gastric_cancer_NR)=get_sorted_patients()
    TILs_Info=get_TILs_Info()

    Mm_R_Tils=pd.merge(TILs_Info,metastatic_melanoma_R,left_on='sample',right_on='Run')
    Mm_NR_Tils=pd.merge(TILs_Info,metastatic_melanoma_NR,left_on='sample',right_on='Run')
    Mgc_R_Tils=pd.merge(TILs_Info,metastatic_gastric_cancer_R,left_on='sample',right_on='Run')
    Mgc_NR_Tils=pd.merge(TILs_Info,metastatic_gastric_cancer_NR,left_on='sample',right_on='Run')
    return(Mm_R_Tils,Mm_NR_Tils,Mgc_R_Tils,Mgc_NR_Tils)

def write_tilsInfo_to_excel(group1,group2,group3,group4):
    g1=group1.iloc[:,0:25]
    g2=group2.iloc[:,0:25]
    g3=group3.iloc[:,0:25]
    g4=group4.iloc[:,0:25]
    writer=pd.ExcelWriter('../data/all_tils_pInfo.xlsx')
    g1.to_excel(writer,'Sheet1')
    g2.to_excel(writer,'Sheet2')
    g3.to_excel(writer,'Sheet3')
    g4.to_excel(writer,'Sheet4')
    writer.save()

def read_excel(index):
    (group1,group2,group3,group4)=join_TILs_Patients_Info()
    write_tilsInfo_to_excel(group1,group2,group3,group4)

    TILs_R_NR=xlrd.open_workbook('../data/all_tils_pInfo.xlsx')
    mm_r=TILs_R_NR.sheet_by_index(0)
    mm_nr=TILs_R_NR.sheet_by_index(1)
    mgc_r=TILs_R_NR.sheet_by_index(2)
    mgc_nr=TILs_R_NR.sheet_by_index(3)
    cols_1=mm_r.col_values(index)[1:23]
    cols_2=mm_nr.col_values(index)[1:23]
    cols_3=mgc_r.col_values(index)[1:23]
    cols_4=mgc_nr.col_values(index)[1:23]
    
    return(cols_1,cols_2,cols_3,cols_4)

def read_excel2(index):
    TILs_R_NR=xlrd.open_workbook('../data/all_tils_pInfo.xlsx')
    cohort_responding=TILs_R_NR.sheet_by_index(2)#mgc
    cohort_non_responding=TILs_R_NR.sheet_by_index(3)#mgc
    cols_1=cohort_responding.col_values(index)
    cols_2=cohort_non_responding.col_values(index)
    del cols_1[0]
    del cols_2[0]
    return(cols_1,cols_2)

def get_pval(group1,group2):

    s, pVal = stats.ranksums(group1, group2) #  
    return(pVal)

def caculate():
    pv=[]
    for i in range(26):
        if i==0 or i==1:
            continue
        (g1,g2)=read_excel2(i)
        pv.append(get_pval(g1,g2))
        
    return(pv)
    
def draw_boxplot():
    f,ax = plt.subplots(figsize=(15,12))
    f.subplots_adjust(left=0.05,right=0.90,bottom=0.20
        ,top=0.90,wspace=0.2,hspace=0.2 )
    (mm_order_sorted,mgc_order_sorted)=Order_sorted()
    path='../data/mgc_boxplot.xlsx' #mgc
    excel=pd.ExcelFile(path)
    mgc=pd.read_excel(excel) #mgc
    
    plt.xticks(rotation=60)


    sns.boxplot(x="cell_type", y="amount", hue="response_type",data=mgc, palette="Set3",
    order=mgc_order_sorted,fliersize=0,ax=ax) #data=mgc
    
    pv=caculate()
    pvdict=dict(zip(c_t,pv))
    colorlist=['black','red']
    index=0
    for i in range(24):
        if pvdict[mgc_order_sorted[i]]<0.05:#mgc
            index=1
        else:
            index=0
        ax.text(x=i, y=0.9, s='%.3f' % pvdict[mgc_order_sorted[i]], color=colorlist[index],horizontalalignment='center') #mgc
    

    plt.show()

def transform_data(gx,r_t):
    gr_x=pd.DataFrame()

    for i in range(24):
        tmp=gx.iloc[:,i:i+1]
        tmp.columns=['amount']
        tmp['response_type']=r_t
        tmp['cell_type']=c_t[i]
        gr_x=gr_x.append(tmp)

    return(gr_x)
 

def data_pre_boxplot():
    (group1,group2,group3,group4)=join_TILs_Patients_Info()

    g1=group1.iloc[:,1:25]
    g2=group2.iloc[:,1:25]
    g3=group3.iloc[:,1:25]
    g4=group4.iloc[:,1:25]

    g1=transform_data(g1,'R')
    g2=transform_data(g2,'NR')    
    g3=transform_data(g3,'R')
    g4=transform_data(g4,'NR')
    
    mm_join=pd.concat([g1,g2])
    mgc_join=pd.concat([g3,g4])
    mm_join.to_excel('../data/mm_boxplot.xlsx')
    mgc_join.to_excel('../data/mgc_boxplot.xlsx')

def Order_sorted():
    mm_or_tmp=[]
    mgc_or_tmp=[]
    for i in range(26):
        if i==0 or i==1:
            continue
        (g1,g2,g3,g4)=read_excel(i)
        m1=np.median(np.array(g1))
        m2=np.median(np.array(g2))
        m3=np.median(np.array(g3))
        m4=np.median(np.array(g4))
        mm_or_tmp.append((m1+m2)/2)
        mgc_or_tmp.append((m3+m4)/2)
    mm_order=dict(zip(c_t,mm_or_tmp))
    mgc_order=dict(zip(c_t,mgc_or_tmp))
    mm_order=sorted(mm_order.items(),key = lambda x:x[1])
    mgc_order=sorted(mgc_order.items(),key = lambda x:x[1])
    
    mm_order_sorted=[]
    mgc_order_sorted=[]
    for i in range(24):
        mm_order_sorted.append(mm_order[i][0])
    for i in range(24):
        mgc_order_sorted.append(mgc_order[i][0])
    return(mm_order_sorted,mgc_order_sorted)

def main():
    data_pre_boxplot()
    draw_boxplot()


if __name__ == '__main__':
    main()