SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Kevin Whittaker
-- Create date: 15 February 2012
-- Description:	Creates the Progress and aspProgress record for a new user
-- Returns:		0 : success, progress created
--       		1 : Failed - progress already exists
--       		100 : Failed - CentreID and CustomisationID don't match
--       		101 : Failed - CentreID and CandidateID don't match

-- V3 changes include:

-- Checks that existing progress hasn't been Removed or Refreshed before returining error.
-- Adds parameters for Enrollment method and admin ID
-- =============================================
ALTER PROCEDURE [dbo].[uspCreateProgressRecord_V3]
	@CandidateID int,
	@CustomisationID int,
	@CentreID int,
	@EnrollmentMethodID int,
	@EnrolledByAdminID int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	--
	-- There are various things to do so wrap this in a transaction
	-- to prevent any problems.
	--
	declare @_ReturnCode integer
	set @_ReturnCode = 0
	BEGIN TRY
		BEGIN TRANSACTION CreateProgress
		--
		-- Check if the chosen CentreID and CustomisationID match
		--
		if (SELECT COUNT(*) FROM Customisations c WHERE (c.CustomisationID = @CustomisationID) AND (c.Active = 1) AND ((c.CentreID = @CentreID) OR (c.AllCentres = 1 AND (EXISTS(SELECT CentreApplicationID FROM CentreApplications WHERE ApplicationID = c.ApplicationID AND CentreID = @CentreID AND Active = 1))))) = 0 
			begin
			set @_ReturnCode = 100
			raiserror('Error', 18, 1)
			end
			if (SELECT COUNT(*) FROM Candidates c WHERE (c.CandidateID = @CandidateID) AND (c.CentreID = @CentreID)) = 0 
			begin
			set @_ReturnCode = 101
			raiserror('Error', 18, 1)
			end
			-- This is being changed (18/09/2018) to check if existing progress hasn't been refreshed or removed:
			if (SELECT COUNT(*) FROM Progress p WHERE (p.CandidateID = @CandidateID) AND (p.CustomisationID = @CustomisationID) AND (SystemRefreshed = 0) AND (RemovedDate IS NULL)) > 0 
			begin
			set @_ReturnCode = 1
			raiserror('Error', 18, 1)
			end
		-- Insert record into progress
		
		INSERT INTO Progress
						(CandidateID, CustomisationID, CustomisationVersion, SubmittedTime, EnrollmentMethodID, EnrolledByAdminID)
			VALUES		(@CandidateID, @CustomisationID, (SELECT C.CurrentVersion FROM Customisations As C WHERE C.CustomisationID = @CustomisationID), 
						 GETUTCDATE(), @EnrollmentMethodID, @EnrolledByAdminID)
		-- Get progressID
		declare @ProgressID integer
		Set @ProgressID = (SELECT SCOPE_IDENTITY())
		-- Insert records into aspProgress
		INSERT INTO aspProgress
		(TutorialID, ProgressID)
		(SELECT     T.TutorialID, @ProgressID as ProgressID
FROM         Customisations AS C INNER JOIN
                      Applications AS A ON C.ApplicationID = A.ApplicationID INNER JOIN
                      Sections AS S ON A.ApplicationID = S.ApplicationID INNER JOIN
                      Tutorials AS T ON S.SectionID = T.SectionID
WHERE     (C.CustomisationID = @CustomisationID) )
		
		--
		-- All finished
		--
		COMMIT TRANSACTION CreateProgress
		--
		-- Decide what the return code should be - depends on whether they
		-- need to be approved or not
		--
		set @_ReturnCode = 0					-- assume that user is registered
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0 
			ROLLBACK TRANSACTION CreateProgress
	END CATCH
	--
	-- Return code indicates errors or success
	--
	SELECT @_ReturnCode
END
GO

/****** Object:  StoredProcedure [dbo].[UpdateCustomisation_V3]    Script Date: 16/10/2020 14:41:01 ******/
DROP PROCEDURE [dbo].[UpdateCustomisation_V3]
GO

DROP PROCEDURE [dbo].[UpdateFilteredLearningActivity]
GO
