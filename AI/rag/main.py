import os
import torch
from typing import List, Dict, Any
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_chroma import Chroma
from langchain_community.llms.tongyi import Tongyi
from langchain.chains.retrieval_qa.base import RetrievalQA
from langchain_community.document_loaders import PyPDFLoader, TextLoader, DirectoryLoader
from langchain_huggingface import HuggingFaceEmbeddings

# 1. 配置阿里云Qwen API Key
DASHSCOPE_API_KEY = "sk-abc123"  # 替换为你的实际Key
os.environ["DASHSCOPE_API_KEY"] = DASHSCOPE_API_KEY
os.environ['HF_ENDPOINT'] = 'https://hf-mirror.com'
os.environ['HF_HUB_DOWNLOAD_TIMEOUT'] = '600'

# 2. 初始化Qwen API模型
def init_qwen_api_llm():
    """初始化阿里云Qwen API的LLM"""
    llm = Tongyi(
        model_name="qwen-turbo",
        dashscope_api_key=os.getenv("DASHSCOPE_API_KEY"),
        temperature=0.3,
        top_p=0.9,
        max_tokens=1024
    )
    return llm

# 3. 文档处理和向量存储（与之前相同）
def load_and_split_documents(data_dir: str = "docs") -> List[Dict[str, Any]]:
    loaders = [
        DirectoryLoader(data_dir, glob="**/*.txt", loader_cls=TextLoader),
        DirectoryLoader(data_dir, glob="**/*.pdf", loader_cls=PyPDFLoader)
    ]
    documents = []
    for loader in loaders:
        docs = loader.load()
        for doc in docs:
            # 确保每个文档有唯一标识
            doc.metadata["document_id"] = os.path.basename(doc.metadata["source"])
        documents.extend(loader.load())
    
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=500,
        chunk_overlap=50,
        separators=["\n\n", "\n", ".", "!", "?", "，", "。", "；"]
    )
    return text_splitter.split_documents(documents)

def create_vector_store(documents, persist_dir: str = "vector_store"):
    # 生成唯一ID格式: 文件名_块索引
    ids = [
        f"{os.path.basename(doc.metadata['source'])}_{i}" 
        for i, doc in enumerate(documents)
    ]
    embeddings = HuggingFaceEmbeddings(
        model_name="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        model_kwargs={"device": "cuda" if torch.cuda.is_available() else "cpu"}
    )
    vector_store = Chroma.from_documents(
        documents=documents,
        embedding=embeddings,
        persist_directory=persist_dir,
        ids=ids  # 显式指定唯一ID
    )
    return vector_store

# 4. 构建RAG系统（使用Qwen API）
def build_rag_system_with_api(vector_store_path: str = "vector_store"):
    # 加载向量存储
    embeddings = HuggingFaceEmbeddings(
        model_name="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
    )
    vector_store = Chroma(
        persist_directory=vector_store_path,
        embedding_function=embeddings
    )

    # 初始化Qwen API LLM
    llm = init_qwen_api_llm()
    
    retriever = vector_store.as_retriever(
        search_type="mmr",  # 使用最大边际相关性算法
        search_kwargs={
            "k": 2,
            "lambda_mult": 0.5  # 多样性控制参数
        }
    )

    # 创建检索QA链
    qa_chain = RetrievalQA.from_chain_type(
        llm=llm,
        chain_type="stuff",
        retriever=retriever,
        return_source_documents=True
    )
    return qa_chain

# 5. 主函数
def main():
    data_directory = "docs"
    vector_store_path = "vector_store"
    
    # 第一步：处理文档（只需一次）
    if not os.path.exists(vector_store_path):
        print("处理文档并创建向量存储...")
        documents = load_and_split_documents(data_directory)
        create_vector_store(documents, vector_store_path)
    
    # 第二步：构建RAG系统
    print("初始化RAG系统（使用Qwen API）...")
    rag_system = build_rag_system_with_api(vector_store_path)
    
    # 第三步：交互式问答
    print("\n开始问答（输入'exit'退出）:")
    while True:
        query = input("\n请输入问题: ")
        if query.lower() == "exit":
            break
        
        result = rag_system({"query": query})
        print("\n回答:")
        print(result["result"])
        
        print("\n参考文档:")
        for i, doc in enumerate(result["source_documents"]):
            print(f"{i+1}. {doc.metadata.get('source', '未知来源')}")

if __name__ == "__main__":
    main()
