#!/bin/bash

CLUSTER_ID="crypto-pipeline-redshift"
REGION="eu-central-1"

case "$1" in
  pause)
    echo "⏸️  Pausing Redshift cluster..."
    aws redshift pause-cluster \
      --cluster-identifier $CLUSTER_ID \
      --region $REGION
    echo "✅ Cluster pausing (takes ~1 minute)"
    ;;
    
  resume)
    echo "▶️  Resuming Redshift cluster..."
    aws redshift resume-cluster \
      --cluster-identifier $CLUSTER_ID \
      --region $REGION
    echo "✅ Cluster resuming (takes 2-3 minutes)"
    ;;
    
  status)
    echo "📊 Checking cluster status..."
    aws redshift describe-clusters \
      --cluster-identifier $CLUSTER_ID \
      --region $REGION \
      --query 'Clusters[0].ClusterStatus' \
      --output text
    ;;
    
  cost)
    echo "💰 Estimated cost if running 24/7:"
    echo "   Per hour:  $0.25"
    echo "   Per day:   $6.00"
    echo "   Per week:  $42.00"
    echo ""
    echo "💡 Your $200 credit lasts ~33 days if always on"
    echo "💡 Pause when not using to save money!"
    ;;
    
  *)
    echo "Usage: $0 {pause|resume|status|cost}"
    exit 1
    ;;
esac