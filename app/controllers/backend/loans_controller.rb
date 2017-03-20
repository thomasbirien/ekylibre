# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2013 Brice Texier, David Joulin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

module Backend
  class LoansController < Backend::BaseController
    manage_restfully

    unroll

    def self.loans_conditions
      code = ''
      code = search_conditions(loans: [:name, :amount], cashes: [:bank_name]) + " ||= []\n"
      code << "if params[:repayment_period].present?\n"
      code << "  c[0] << ' AND #{Loan.table_name}.repayment_period IN (?)'\n"
      code << "  c << params[:repayment_period]\n"
      code << "end\n"
      code.c
    end

    list(conditions: loans_conditions, selectable: true) do |t|
      t.action :edit
      t.action :destroy
      t.column :name, url: true
      t.column :amount, currency: true
      t.column :cash, url: true
      t.column :started_on
      t.column :repayment_duration
      t.column :repayment_period
      t.column :shift_duration
    end

    list :repayments, model: :loan_repayments, conditions: { loan_id: 'params[:id]'.c } do |t|
      t.action :edit
      t.column :position
      t.column :due_on
      t.column :amount, currency: true
      t.column :base_amount, currency: true
      t.column :interest_amount, currency: true
      t.column :insurance_amount, currency: true
      t.column :remaining_amount, currency: true
      t.column :journal_entry, url: true, hidden: true
    end

    def confirm
      return unless @loan = find_and_check
      @loan.confirm
      redirect_to action: :show, id: @loan.id
    end

    def repay
      return unless @loan = find_and_check
      @loan.repay
      redirect_to action: :show, id: @loan.id
    end

    def generate_repayments_up_to

      begin  
        date = Date.parse(params[:generate_repayments_date])
      rescue
        notify_error(:error_while_depreciating)
        return redirect_to(params[:redirect] || { action: :index })
      end
     
      loans_ids = JSON.parse(params[:loans_ids])
      loans_ids.find_each do |loan_id|
        loan = Loan.find(loan_id)
        loan.repayments.find_each { |repayment| repayment.update(accountable: true) }
      end

      return redirect_to(params[:redirect] || { action: :index })
    end
  end
end
