resource "aws_budgets_budget" "ec2-budget" {
  name              = "presupuesto-mensual-lab"
  budget_type       = "COST"
  limit_amount      = "1.0"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 0.50
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["bogdanturcu130504@gmail.com"]
  }

  tags = {
    Owner = "Bogdan Turcu"
  }
}