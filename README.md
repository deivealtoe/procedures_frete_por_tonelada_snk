### Valor do Frete por Região e Tonelada

O objetivo destas procedures é de fazer o cálculo do frete dos itens marcados como entrega.

Sendo os valores de forma que

- Valor base do frete é o valor definido na região cadastrada no cliente
- Se o peso da data de entrega for menor ou igual a 1000Kg, o valor do frete deve ser apenas o valor definido na região
- Se o peso da data de entrega for maior que 1000Kg, o valor do frete deverá ser o valor definido na região, mais o peso excedido multiplicado por uma taxa de R$0,08
  - Peso total da data de entrega: 1200Kg
  - Valor da taxa: R$0,08
  - Cálculo: ((peso total - 1000) * valor da taxa) + valor do frete da região
    - Colocando em prática: (1200 - 1000) * 0,08) + 60 