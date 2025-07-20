helm repo add bitnami <https://charts.bitnami.com/bitnami> && helm repo update && helm install my-kafka bitnami/kafka -n kafka --create-namespace -f 6-nemo-cloud/v3/dev/charts/data/kafka/values.yaml

helm upgrade my-kafka bitnami/kafka -n kafka -f 6-nemo-cloud/v3/dev/charts/data/kafka/values.yaml

helm upgrade --install kafka bitnami/kafka -n kafka --create-namespace -f /home/ubuntu/6-nemo-cloud/v3/dev/charts/data/kafka/values.yaml

helm uninstall my-kafka -n kafka && helm upgrade --install kafka bitnami/kafka -n kafka --create-namespace -f /home/ubuntu/6-nemo-cloud/v3/dev/charts/data/kafka/values.yaml
