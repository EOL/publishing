module RefineryAdminControllerAuthenticationDecorator
  protected

  def authenticate_refinery_user!
   @user =  authenticate_user!
   redirect_to root_path unless @user.admin
  end
end

Refinery::AdminController.send :prepend, RefineryAdminControllerAuthenticationDecorator